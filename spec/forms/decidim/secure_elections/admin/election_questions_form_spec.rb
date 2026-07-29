# frozen_string_literal: true

require "spec_helper"

module Decidim
  module SecureElections
    module Admin
      # Step 2 of the wizard: the ballot. Questions and their options arrive
      # together, in one submit, so that adding an option costs no page load.
      describe ElectionQuestionsForm do
        subject(:form) { described_class.from_params(attributes).with_context(context) }

        let(:organization) { create(:organization, available_locales: [:en]) }
        let(:participatory_space) { create(:participatory_process, organization:) }
        let(:component) { create(:vocdoni_component, participatory_space:) }
        let(:election) { nil }
        let(:context) { { current_organization: organization, current_component: component, election: } }

        let(:option_attributes) do
          {
            "0" => { title_en: "Yes" },
            "1" => { title_en: "No" }
          }
        end

        let(:question_attributes) do
          {
            "0" => {
              uid: "q0",
              title_en: "Do you agree?",
              description_en: "",
              answers: option_attributes
            }
          }
        end

        let(:attributes) do
          {
            election: {
              question_type: "singlechoice",
              result_visibility: "live",
              questions: question_attributes
            }
          }
        end

        it { is_expected.to be_valid }

        it "reads the whole ballot in one submit" do
          expect(form.questions.size).to eq(1)
          expect(form.questions.first.answers.size).to eq(2)
        end

        describe "questions" do
          context "when a question has a single option" do
            before { attributes[:election][:questions]["0"][:answers] = { "0" => { title_en: "Yes" } } }

            it "is refused: one option is not a choice" do
              expect(form).to be_invalid
            end
          end

          # The reported failure: the flash said "there was a problem saving the
          # questions" and nothing on the page said *which* field. With several
          # questions on one page that is a hunt.
          context "when one option is filled in and the other is left empty" do
            before do
              attributes[:election][:questions]["0"][:answers] = {
                "0" => { title_en: "Yes" },
                "1" => { title_en: "" }
              }
            end

            it { is_expected.to be_invalid }

            it "reports the empty option on the option itself" do
              form.invalid?

              blank_option = form.questions.first.answers.last

              expect(blank_option.errors[:title_en]).to be_present
            end

            it "still says on the question what the ballot is missing" do
              form.invalid?

              expect(form.questions.first.errors[:answers]).to be_present
            end

            it "keeps what the admin typed" do
              form.invalid?

              expect(form.questions.first.answers.first.title["en"]).to eq("Yes")
            end
          end

          context "when an option was added and left empty" do
            before { attributes[:election][:questions]["0"][:answers]["2"] = { title_en: "" } }

            it { is_expected.to be_valid }

            it "drops it instead of reporting it" do
              expect(form.questions.first.options.size).to eq(2)
            end

            it "does not flag a spare row on a question that is already valid" do
              form.valid?

              expect(form.questions.first.answers.last.errors).to be_empty
            end
          end

          context "when a whole question card was added and left empty" do
            before do
              attributes[:election][:questions]["1"] = {
                uid: "q1",
                title_en: "",
                description_en: "",
                answers: { "0" => { title_en: "" }, "1" => { title_en: "" } }
              }
            end

            it { is_expected.to be_valid }

            it "is not persisted" do
              expect(form.submitted_questions.size).to eq(1)
            end
          end

          # The reported failure: saving an untouched ballot answered with the
          # flash "There was a problem saving the questions." and no mark
          # anywhere on the page, so nothing said which of the fields in front
          # of the admin the flash was about.
          context "when every question is empty" do
            before { attributes[:election][:questions]["0"] = { uid: "q0", title_en: "", description_en: "", answers: {} } }

            it { is_expected.to be_invalid }

            it "says what the ballot is missing" do
              form.invalid?

              expect(form.ballot_error).to eq("Add at least one question: an election with nothing on the ballot has nothing to vote on.")
            end

            it "flags the first question so the page is not blank" do
              form.invalid?

              expect(form.questions.first.errors[:title_en]).to be_present
            end
          end

          context "when a question has options but no title" do
            before { attributes[:election][:questions]["0"][:title_en] = "" }

            it { is_expected.to be_invalid }
          end

          # The reported failure: "Audit" / "Audit" / "Budget" saved with
          # "Questions saved successfully". Once published that ballot offers
          # the same choice twice for ever, and the results show two rows with
          # nothing to tell them apart.
          describe "options that say the same thing" do
            before do
              attributes[:election][:questions]["0"][:answers] = {
                "0" => { title_en: "Audit" },
                "1" => { title_en: "Audit" },
                "2" => { title_en: "Budget" }
              }
            end

            it { is_expected.to be_invalid }

            it "says on the question why a ballot cannot carry them" do
              form.invalid?

              expect(form.questions.first.errors[:answers].join(" "))
                .to eq("Two of these options say the same thing: a voter cannot tell them apart on the ballot, and the " \
                       "results would show them as two identical rows. Reword one of them, or remove it. Options in " \
                       "different questions may repeat.")
            end

            it "flags both offending inputs and leaves the innocent one alone" do
              form.invalid?

              answers = form.questions.first.answers

              expect(answers[0].errors[:title_en]).to eq(["This option says the same as another one in this question."])
              expect(answers[1].errors[:title_en]).to eq(["This option says the same as another one in this question."])
              expect(answers[2].errors).to be_empty
            end
          end

          context "when two options differ only in case and surrounding space" do
            before do
              attributes[:election][:questions]["0"][:answers] = {
                "0" => { title_en: "Audit" },
                "1" => { title_en: "  audit " }
              }
            end

            it "is refused: a voter reads them as the same option" do
              expect(form).to be_invalid
            end
          end

          context "when two different questions offer the same option" do
            before do
              attributes[:election][:questions]["1"] = {
                uid: "q1",
                title_en: "Do you agree with the second thing?",
                description_en: "",
                answers: { "0" => { title_en: "Yes" }, "1" => { title_en: "No" } }
              }
            end

            it { is_expected.to be_valid }
          end

          # Empty rows are `enough_options`' business. Reporting a pile of them
          # as duplicates of each other would bury the message that helps.
          context "when several options are left empty" do
            before do
              attributes[:election][:questions]["0"][:answers] = {
                "0" => { title_en: "Yes" },
                "1" => { title_en: "No" },
                "2" => { title_en: "" },
                "3" => { title_en: "" }
              }
            end

            it { is_expected.to be_valid }
          end
        end

        describe "the process-wide question type" do
          before do
            attributes[:election][:question_type] = "multichoice"
            attributes[:election][:questions]["0"][:min_choices] = 1
            attributes[:election][:questions]["0"][:max_choices] = 2
          end

          it "is copied down to every question before validating" do
            form.valid?

            expect(form.questions.map(&:question_type)).to all(eq("multichoice"))
          end

          it "refuses to allow more choices than there are options" do
            attributes[:election][:questions]["0"][:max_choices] = 5

            expect(form).to be_invalid
          end

          # The reported failure: min 5 / max 2 against a question with two
          # options produced a red border and a bare "is invalid" on the
          # maximum. It never named the minimum it contradicted, never mentioned
          # how many options the question offers, and left the minimum — the
          # number that was actually out of range — unflagged.
          describe "the selection limits" do
            subject(:question) { form.questions.first }

            let(:limits) { {} }

            before do
              attributes[:election][:questions]["0"].merge!(limits)
              form.invalid?
            end

            context "when the minimum is above the maximum and both are above the option count" do
              let(:limits) { { min_choices: 5, max_choices: 2 } }

              it { expect(form).to be_invalid }

              it "flags the minimum against the options it is measured on" do
                expect(question.errors[:min_choices].join(" "))
                  .to eq("This question offers 2 options, so nobody can be asked to pick more than 2. Lower this number, or add more options.")
              end

              it "flags the maximum against the minimum it contradicts" do
                expect(question.errors[:max_choices].join(" "))
                  .to eq("The maximum cannot be lower than the minimum, which is 5. Raise this number, or lower the minimum.")
              end

              # The parent picks up an `:invalid` of its own whenever a nested
              # question fails. It must not reach the top of the page, or every
              # missing option anywhere on the ballot would headline it with
              # "is invalid".
              it "does not headline the page with the nested form's own error" do
                expect(form.ballot_error).to be_nil
              end
            end

            context "when the minimum is above the maximum and both fit the options" do
              let(:limits) { { min_choices: 2, max_choices: 1 } }

              it "names the other number on both fields" do
                expect(question.errors[:min_choices].join(" ")).to include("cannot be higher than the maximum, which is 1")
                expect(question.errors[:max_choices].join(" ")).to include("cannot be lower than the minimum, which is 2")
              end
            end

            context "when only the minimum is above the option count" do
              let(:limits) { { min_choices: 3, max_choices: nil } }

              it { expect(form).to be_invalid }

              it "flags the minimum, which the old rule never looked at" do
                expect(question.errors[:min_choices].join(" ")).to include("This question offers 2 options")
              end
            end

            context "when only the maximum is above the option count" do
              let(:limits) { { min_choices: 1, max_choices: 3 } }

              it "says how many options there are rather than \"is invalid\"" do
                expect(question.errors[:max_choices].join(" "))
                  .to eq("This question offers 2 options, so nobody can pick more than 2. Lower this number, or add more options.")
                expect(question.errors[:min_choices]).to be_empty
              end
            end

            # Rails' own "must be greater than 0" was the one raw string left on
            # a form whose other messages say which number to change and why.
            context "when a limit is zero or negative" do
              let(:limits) { { min_choices: -3, max_choices: 0 } }

              it { expect(form).to be_invalid }

              it "says what to set it to rather than restating the constraint" do
                expect(question.errors[:min_choices].join(" "))
                  .to eq("A voter has to be asked for at least one option. Set this to 1 or more, or leave it empty for no lower limit.")
                expect(question.errors[:max_choices].join(" "))
                  .to eq("A voter has to be allowed at least one option. Set this to 1 or more, or leave it empty for no upper limit.")
              end

              it "never says \"must be greater than\"" do
                expect(question.errors.full_messages.join(" ")).not_to include("greater than 0")
              end
            end

            context "when the limits agree with each other and with the ballot" do
              let(:limits) { { min_choices: 1, max_choices: 2 } }

              it { expect(form).to be_valid }
            end
          end

          context "when the type is single choice" do
            before { attributes[:election][:question_type] = "singlechoice" }

            it "ignores the choice bounds rather than rejecting them" do
              expect(form).to be_valid
              expect(form.questions.first.max_choices).to be_nil
            end
          end
        end

        describe "#secret_until_the_end?" do
          it "is false for live results" do
            expect(form).not_to be_secret_until_the_end
          end

          context "when results are hidden until the end" do
            before { attributes[:election][:result_visibility] = "hidden" }

            it { is_expected.to be_secret_until_the_end }
          end
        end

        describe ".from_model" do
          subject(:form) { described_class.from_model(election).with_context(context) }

          let(:election) { create(:vocdoni_election, :with_questions, component:, questions_count: 2, answers_count: 3) }

          it "loads the whole ballot" do
            expect(form.questions.size).to eq(2)
            expect(form.questions.map { |question| question.answers.size }).to all(eq(3))
          end

          it "derives the process-wide settings from the questions" do
            expect(form.question_type).to eq("singlechoice")
            expect(form.result_visibility).to eq("live")
          end

          context "when the election has no questions yet" do
            let(:election) { create(:vocdoni_election, component:) }

            it "opens with one empty question so there is something to edit" do
              expect(form.questions.size).to eq(1)
              expect(form.questions.first.answers.size).to eq(2)
            end
          end
        end
      end
    end
  end
end
