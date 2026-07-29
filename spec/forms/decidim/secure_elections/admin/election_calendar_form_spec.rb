# frozen_string_literal: true

require "spec_helper"

module Decidim
  module SecureElections
    module Admin
      # Step 4 of the wizard: when voting happens.
      describe ElectionCalendarForm do
        subject(:form) { described_class.from_params(attributes).with_context(context) }

        let(:organization) { create(:organization, available_locales: [:en]) }
        let(:participatory_space) { create(:participatory_process, organization:) }
        let(:component) { create(:vocdoni_component, participatory_space:) }
        let(:election) { nil }
        let(:context) { { current_organization: organization, current_component: component, election: } }

        let(:attributes) do
          {
            election: {
              start_immediately: true,
              end_time: 2.days.from_now
            }
          }
        end

        it { is_expected.to be_valid }

        context "when there is no end time" do
          before { attributes[:election][:end_time] = nil }

          it { is_expected.to be_invalid }
        end

        context "when the end time is in the past" do
          before { attributes[:election][:end_time] = 2.days.ago }

          it { is_expected.to be_invalid }

          # The `date:` validator interpolated the raw restriction, so an admin
          # picking yesterday was answered with
          # "must be after Mon, 27 Jul 2026 21:54:36 +0000" — a format that
          # appears nowhere else in Decidim, in a zone they never chose.
          it "says so in the format the rest of the admin uses" do
            form.invalid?
            message = form.errors[:end_time].join(" ")

            expect(message).to include("must be in the future")
            expect(message).to include(I18n.l(Time.current, format: :decidim_short))
            expect(message).not_to match(/[A-Z][a-z]{2}, \d{2} [A-Z][a-z]{2} \d{4}/)
          end
        end

        describe "the start time" do
          it "is stored as NULL when the election starts on publication" do
            expect(form.effective_start_time).to be_nil
          end

          context "when a start time is scheduled" do
            before do
              attributes[:election][:start_immediately] = false
              attributes[:election][:start_time] = 1.day.from_now
            end

            it { is_expected.to be_valid }

            it "keeps the value" do
              expect(form.effective_start_time).to be_within(1.minute).of(1.day.from_now)
            end
          end

          context "when a start time is scheduled but not given" do
            before { attributes[:election][:start_immediately] = false }

            it { is_expected.to be_invalid }
          end

          context "when the start time is after the end time" do
            before do
              attributes[:election][:start_immediately] = false
              attributes[:election][:start_time] = 3.days.from_now
            end

            it { is_expected.to be_invalid }
          end

          # A typo'd year used to save in silence, take the publish checklist
          # to all-green and print "Start time 01/01/2020 10:00" on the "what
          # will be published" panel without a word — right up to the button
          # that spends real tokens. Upstream would not have refused it either:
          # the SaaS backend moves any non-future `startDate` to "now", so the
          # election would simply have opened on publication under a start time
          # it never had.
          context "when the start time is in the past" do
            before do
              attributes[:election][:start_immediately] = false
              attributes[:election][:start_time] = 2.days.ago
            end

            it { is_expected.to be_invalid }

            it "says so in the format the rest of the admin uses, and names the fix" do
              form.invalid?
              message = form.errors[:start_time].join(" ")

              expect(message).to include("must be in the future")
              expect(message).to include(I18n.l(Time.current, format: :decidim_short))
              expect(message).to include("Start immediately")
              expect(message).not_to match(/[A-Z][a-z]{2}, \d{2} [A-Z][a-z]{2} \d{4}/)
            end
          end

          # "Start immediately" is a NULL start time, so there is no value to
          # be in the past and nothing to report.
          context "when the start time is in the past but the election starts on publication" do
            before do
              attributes[:election][:start_immediately] = true
              attributes[:election][:start_time] = 2.days.ago
            end

            it { is_expected.to be_valid }

            it "stores no start time at all" do
              expect(form.effective_start_time).to be_nil
            end
          end

          # An election that is already on chain legitimately has a start time
          # in the past — it is running, or it has run. Re-validating one would
          # make an existing record unsaveable and break the read-only screens
          # that render this form.
          context "when the election is already on chain" do
            let(:election) { create(:vocdoni_election, :on_chain, component:) }

            before do
              attributes[:election][:start_immediately] = false
              attributes[:election][:start_time] = 2.days.ago
              attributes[:election][:end_time] = 2.days.ago + 1.hour
            end

            it { is_expected.to be_valid }
          end
        end

        describe ".from_model" do
          subject(:form) { described_class.from_model(election).with_context(context) }

          let(:election) { create(:vocdoni_election, component:, start_time: nil) }

          it "marks a null start time as starting on publication" do
            expect(form.start_immediately).to be(true)
          end
        end
      end
    end
  end
end
