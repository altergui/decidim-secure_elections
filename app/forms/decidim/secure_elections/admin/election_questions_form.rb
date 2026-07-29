# frozen_string_literal: true

module Decidim
  module SecureElections
    module Admin
      # Step 2 of the wizard: the ballot.
      #
      # Questions **and** their options are on this one form: adding an option
      # must not cost a page load, so the options are nested attributes of the
      # questions, which are nested attributes of this form, and the whole
      # ballot arrives in a single submit.
      #
      # Two things are decided here once and copied down to every question,
      # mirroring the Vocdoni app even though the database keeps them per
      # question (ARCHITECTURE §4d):
      #
      # * `question_type` — the app calls it "This applies to all questions in
      #   this voting process".
      # * `result_visibility` — "live" or "hidden until the end", which is the
      #   per-question `secret_until_the_end` column.
      class ElectionQuestionsForm < Decidim::Form
        mimic :election

        include Decidim::TranslatableAttributes

        # Results are readable while voting is open, or only once the
        # keykeepers publish the encryption keys.
        RESULT_VISIBILITIES = %w(live hidden).freeze

        attribute :question_type, String, default: "singlechoice"
        attribute :result_visibility, String, default: "live"

        attribute :questions, [QuestionForm]

        validates :question_type, inclusion: { in: Decidim::SecureElections::Question::QUESTION_TYPES }
        validates :result_visibility, inclusion: { in: RESULT_VISIBILITIES }
        validate :at_least_one_question

        def map_model(election)
          self.question_type = election.questions.first&.question_type || "singlechoice"
          self.result_visibility = election.questions.any?(&:secret_until_the_end?) ? "hidden" : "live"

          self.questions = election.questions.map { |question| QuestionForm.from_model(question) }
          ensure_default_questions!
        end

        def election
          @election ||= context[:election]
        end

        def editable?
          election.nil? || election.editable?
        end

        def multichoice?
          question_type == "multichoice"
        end

        # "Hidden until the end" is the per-question `secret_until_the_end`
        # column: no partial tally is readable until the keys are published.
        def secret_until_the_end?
          result_visibility == "hidden"
        end

        # The questions that will actually be persisted. A card the admin added
        # and left completely empty is dropped instead of being reported, the
        # same way an empty option is.
        def submitted_questions
          questions.reject(&:unfilled?)
        end

        # The database ids the browser does not know about yet, keyed by the
        # client-side identity of each row.
        #
        # This is what makes repeated autosaves idempotent: a question the admin
        # added in the browser has no `id` on the first save, and without
        # handing it back the second save would create it all over again.
        #
        # Only meaningful after a command has run — that is what fills the ids
        # in.
        #
        # @return [Hash] `{ "q0" => { "id" => 5, "answers" => { "q0-a0" => 9 } } }`
        def saved_ids
          submitted_questions.each_with_object({}) do |question, acc|
            next if question.uid.blank?

            acc[question.uid] = {
              "id" => question.id,
              "answers" => question.options.each_with_object({}) do |answer, answers|
                answers[answer.uid] = answer.id if answer.uid.present?
              end
            }
          end
        end

        # The one ballot-level sentence worth putting above the questions.
        #
        # `errors[:questions]` cannot simply be rendered: the form object adds a
        # bare `:invalid` to the parent whenever *any* nested question fails,
        # which would put "is invalid" at the top of the page every time a
        # single option was left empty three cards down — precisely the
        # unhelpful noise this screen exists to get rid of. Only the message
        # about the ballot as a whole belongs here; everything else is already
        # reported on the input it belongs to.
        #
        # @return [String, nil]
        def ballot_error
          errors.where(:questions, :blank).first&.message
        end

        # Makes sure the editor always has something to edit. A brand new
        # ballot opens with one question and two empty options, exactly like
        # the Vocdoni app.
        def ensure_default_questions!
          self.questions = [QuestionForm.blank_question] if questions.blank?
          self
        end

        # Every question of a process shares its type and its result visibility.
        # They are copied down here rather than rendered as hidden fields per
        # question, so that a tampered request cannot produce a process whose
        # questions disagree with each other.
        def valid?(validation_context = nil)
          questions.each { |question| question.question_type = question_type }
          super
        end

        private

        # A ballot with nothing on it is refused, and the *input* that would fix
        # it says so.
        #
        # An untouched card is dropped rather than reported (`QuestionForm#
        # unfilled?`), which is right when there is another question to save and
        # wrong when there is not: saving an untouched page answered with a lone
        # flash left the admin looking at a screen with no mark on it anywhere,
        # wondering which of the fields in front of them the flash meant.
        def at_least_one_question
          return if submitted_questions.any?

          errors.add(:questions, :blank)

          # Only the first card. The admin is shown where to start, not scolded
          # for every empty question on the page.
          questions.first&.flag_empty!
        end
      end
    end
  end
end
