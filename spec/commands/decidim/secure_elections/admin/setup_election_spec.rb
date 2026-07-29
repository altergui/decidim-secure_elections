# frozen_string_literal: true

require "spec_helper"

module Decidim
  module SecureElections
    module Admin
      describe SetupElection do
        subject(:command) { described_class.new(form, current_user) }

        let(:organization) { create(:organization) }
        let(:current_user) { create(:user, :admin, :confirmed, organization:) }
        let(:election) { create(:vocdoni_election, :ready_to_publish) }
        let(:invalid) { false }
        let(:form) { double(invalid?: invalid, election:) }

        context "when the form is invalid" do
          let(:invalid) { true }

          it "broadcasts invalid" do
            expect { command.call }.to broadcast(:invalid)
          end

          it "does not enqueue anything" do
            expect { command.call }.not_to have_enqueued_job(Decidim::SecureElections::PublishElectionJob)
          end
        end

        context "when everything is in place" do
          it "broadcasts ok" do
            expect { command.call }.to broadcast(:ok)
          end

          it "moves the election to publishing" do
            command.call
            expect(election.reload.status).to eq("publishing")
          end

          it "hands the blockchain write over to a job instead of doing it inline" do
            expect { command.call }
              .to have_enqueued_job(Decidim::SecureElections::PublishElectionJob).with(election.id)
          end

          it "does not touch the API" do
            expect(Decidim::SecureElections::ApiClient).not_to receive(:new)
            command.call
          end

          it "clears a previous failure" do
            election.update!(results_cache: { "error" => { "message" => "boom" } })

            command.call

            expect(election.reload.results_cache).not_to have_key("error")
          end

          it "traces the action" do
            expect { command.call }.to change(Decidim::ActionLog, :count).by(1)
            expect(Decidim::ActionLog.last.action).to eq("setup")
          end
        end
      end
    end
  end
end
