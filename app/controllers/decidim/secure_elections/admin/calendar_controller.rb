# frozen_string_literal: true

module Decidim
  module SecureElections
    module Admin
      # Step 4 of the wizard: when voting happens.
      #
      # The election either opens the moment it reaches the blockchain, or at a
      # time the admin picks; it always needs an end. Locked until the census is
      # complete, because a schedule for an election nobody can vote in is not
      # worth filling in.
      class CalendarController < Admin::ApplicationController
        wizard_step :calendar

        def edit
          enforce_permission_to(:read, :calendar, election:)

          @form = form(Decidim::SecureElections::Admin::ElectionCalendarForm).from_model(election, election:)
        end

        def update
          enforce_permission_to(:update, :calendar, election:)

          @form = form(Decidim::SecureElections::Admin::ElectionCalendarForm).from_params(params, election:)

          Decidim::SecureElections::Admin::UpdateElectionCalendar.call(@form, election) do
            on(:ok) do
              flash[:notice] = I18n.t("calendar.update.success", scope: "decidim.secure_elections.admin")
              redirect_to next_step_path
            end

            on(:invalid) do
              flash.now[:alert] = I18n.t("calendar.update.invalid", scope: "decidim.secure_elections.admin")
              render action: "edit", status: :unprocessable_content
            end
          end
        end

        private

        def next_step_path
          election.reload
          return secure_elections_step_path(election, :publish) if election.step_reachable?(:publish)

          secure_elections_step_path(election, :calendar)
        end
      end
    end
  end
end
