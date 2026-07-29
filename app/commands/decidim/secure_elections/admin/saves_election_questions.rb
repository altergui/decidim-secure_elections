# frozen_string_literal: true

module Decidim
  module SecureElections
    module Admin
      # Persists the questions and options of the ballot step.
      #
      # The step submits the *whole* ballot every time, so this is a
      # reconciliation rather than a series of edits: what the form carries is
      # what the election ends up with. Questions and options that are no longer
      # in the payload are destroyed, the survivors keep their database id, and
      # everything is renumbered so the on-chain encoding stays contiguous.
      #
      # Two invariants matter more than anything else here:
      #
      # * an option's `value` is the integer written into the ballot, so it is
      #   derived from its position and never read from the request;
      # * `value` is unique per question at the database level, which means a
      #   plain reorder (swapping options 0 and 1, say) would collide halfway
      #   through. Every surviving option is therefore parked on a temporary
      #   value first and given its final one afterwards.
      #
      # Included by `UpdateElectionQuestions`, which runs it inside the command
      # transaction.
      module SavesElectionQuestions
        extend ActiveSupport::Concern

        # Far above any plausible number of options, so the parking values can
        # never collide with a final one.
        VALUE_PARKING_OFFSET = 1_000_000

        private

        # @param election [Decidim::SecureElections::Election]
        # @return [void]
        def save_questions!(election)
          kept = form.submitted_questions.each_with_index.map do |question_form, index|
            save_question!(election, question_form, index).id
          end

          election.questions.where.not(id: kept).destroy_all
          election.questions.reset
        end

        def save_question!(election, question_form, index)
          question = existing_question(election, question_form) || election.questions.build

          question.assign_attributes(
            title: question_form.title,
            description: question_form.description,
            # Set once for the whole process by the editor, stored per question
            # because that is what the schema and the voting page expect.
            question_type: form.question_type,
            secret_until_the_end: form.secret_until_the_end?,
            max_choices: form.multichoice? ? question_form.max_choices : nil,
            min_choices: form.multichoice? ? question_form.min_choices : nil,
            position: index
          )
          question.save!

          # Let the caller hand the new id back to the browser, so that an
          # autosave does not create the same question twice.
          question_form.id = question.id

          save_answers!(question, question_form)

          question
        end

        # Only ever looks inside this election: an id from the request is a
        # claim, not a fact.
        def existing_question(election, question_form)
          return nil if question_form.id.blank?

          election.questions.find_by(id: question_form.id)
        end

        def save_answers!(question, question_form)
          park_existing_values!(question)

          kept = question_form.options.each_with_index.map do |answer_form, index|
            answer = existing_answer(question, answer_form) || question.answers.build
            answer.title = answer_form.title
            answer.position = index
            answer.value = index
            answer.save!

            answer_form.id = answer.id
            answer.id
          end

          question.answers.where.not(id: kept).destroy_all
          question.answers.reset
        end

        def existing_answer(question, answer_form)
          return nil if answer_form.id.blank?

          question.answers.find_by(id: answer_form.id)
        end

        # Moves every stored option out of the 0..n range so that reordering
        # cannot trip the `(question, value)` unique index mid-update. Bypasses
        # validations on purpose: this is bookkeeping, not an editorial change,
        # and the values are overwritten a few lines later anyway.
        def park_existing_values!(question)
          question.answers.reload.each_with_index do |answer, index|
            # rubocop:disable Rails/SkipsModelValidations
            answer.update_columns(value: VALUE_PARKING_OFFSET + index)
            # rubocop:enable Rails/SkipsModelValidations
          end
        end
      end
    end
  end
end
