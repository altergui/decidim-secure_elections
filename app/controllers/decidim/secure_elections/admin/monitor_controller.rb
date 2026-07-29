# frozen_string_literal: true

module Decidim
  module SecureElections
    module Admin
      # The live view of an on-chain election.
      #
      # Everything it renders comes from `results_cache`, `votes_count` and
      # `answers.votes_count` — all local columns. Opening this page, or
      # reloading it, costs exactly zero requests to Vocdoni no matter how many
      # admins are watching. `refresh` is the only way to ask for new numbers,
      # and even that only enqueues `SyncResultsJob`.
      class MonitorController < Admin::ApplicationController
        include ActionView::Helpers::NumberHelper

        # The step after the last one: it only opens once publication has been
        # attempted. Before that there is nothing on chain to monitor.
        wizard_step :monitor

        helper_method :questions

        def show
          enforce_permission_to(:read, :monitor, election:)

          @form = form(Decidim::SecureElections::Admin::QuestionStatusForm).instance(election:)

          respond_to do |format|
            format.html
            # The same page, as data. Read by the pack after a refresh so the
            # figures change in front of the admin instead of only after a
            # reload. Like the HTML, it is a pure read of `results_cache` and
            # the denormalized counters — polling it can never reach Vocdoni
            # (ARCHITECTURE §0.5).
            format.json { render json: monitor_payload }
          end
        end

        def status
          enforce_permission_to(:update_status, :monitor, election:)

          @form = form(Decidim::SecureElections::Admin::QuestionStatusForm).from_params(params, election:)

          Decidim::SecureElections::Admin::UpdateQuestionStatus.call(@form, current_user) do
            on(:ok) do
              flash[:notice] = I18n.t("monitor.status.success", scope: "decidim.secure_elections.admin")
              redirect_to election_monitor_path(election)
            end

            on(:invalid) do
              flash.now[:alert] = I18n.t("monitor.status.invalid", scope: "decidim.secure_elections.admin")
              render action: "show", status: :unprocessable_content
            end
          end
        end

        def refresh
          enforce_permission_to(:refresh, :monitor, election:)

          enqueued = false
          message = nil

          Decidim::SecureElections::Admin::RefreshElection.call(election) do
            on(:ok) do |mode|
              # i18n-tasks-use t("decidim.secure_elections.admin.monitor.refresh.publish")
              # i18n-tasks-use t("decidim.secure_elections.admin.monitor.refresh.results")
              enqueued = true
              message = I18n.t("monitor.refresh.#{mode}", scope: "decidim.secure_elections.admin")
            end

            on(:invalid) do
              message = I18n.t("monitor.refresh.invalid", scope: "decidim.secure_elections.admin")
            end
          end

          respond_to do |format|
            format.html do
              flash[enqueued ? :notice : :alert] = message
              redirect_to election_monitor_path(election)
            end

            # No redirect for the pack: it stays on the page, shows that the
            # request is in flight and polls `show.json` until the job lands.
            # The response only reports that the job was *enqueued* — the
            # reading itself never happens inside a web request.
            format.json do
              render json: { enqueued:, message:, synced_at: election.results_synced_at&.iso8601 },
                     status: enqueued ? :accepted : :unprocessable_content
            end
          end
        end

        private

        def questions
          @questions ||= election.questions.includes(:answers)
        end

        # Everything the monitor shows, as data. Local columns only.
        def monitor_payload
          {
            id: election.id,
            state: election.display_state,
            state_label: helpers.secure_elections_display_state_label(election.display_state),
            upstream_status: helpers.vocdoni_upstream_status_label(election),
            votes_count: election.votes_count,
            census_size: election.census_size,
            turnout_text: helpers.vocdoni_turnout_text(election),
            synced_at: election.results_synced_at&.iso8601,
            synced_text: helpers.secure_elections_last_synced_text(election),
            questions: questions.map { |question| question_payload(question) }
          }
        end

        # `question.votes_count` is ballots cast, not the sum of the per-answer
        # tallies: a multichoice ballot contributes to several answers at once.
        def question_payload(question)
          {
            id: question.id,
            votes_text: t("decidim.secure_elections.admin.monitor.votes_count", count: question.votes_count),
            answers: question.answers.map { |answer| answer_payload(answer) }
          }
        end

        def answer_payload(answer)
          {
            id: answer.id,
            votes_text: t("decidim.secure_elections.admin.monitor.votes_count", count: answer.votes_count.to_i),
            percent_text: number_to_percentage(answer.votes_percent, precision: 1)
          }
        end
      end
    end
  end
end
