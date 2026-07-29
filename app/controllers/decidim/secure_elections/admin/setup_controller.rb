# frozen_string_literal: true

module Decidim
  module SecureElections
    module Admin
      # Step 5 of the wizard: the point of no return.
      #
      # Reachable only when every other step is complete, which is checked in
      # three independent places: the navigation greys it out, `wizard_step`
      # redirects, and `SetupForm` re-validates every precondition before the
      # job is enqueued.
      #
      # `show` is a review-and-confirm screen; `create` records the decision and
      # enqueues `Decidim::SecureElections::PublishElectionJob`. The blockchain write
      # itself happens in that job — this controller never opens a connection.
      class SetupController < Admin::ApplicationController
        # The last of the numbered steps, and the only one whose prerequisites
        # are the whole of the rest: details, ballot, census and schedule. Once
        # the process is on chain the step is over and the guard redirects here
        # to the monitor.
        wizard_step :publish

        def show
          enforce_permission_to(:read, :setup, election:)

          @form = form(Decidim::SecureElections::Admin::SetupForm).instance(election:)
        end

        def create
          enforce_permission_to(:create, :setup, election:)

          @form = form(Decidim::SecureElections::Admin::SetupForm).from_params(params, election:)

          Decidim::SecureElections::Admin::SetupElection.call(@form, current_user) do
            on(:ok) do
              flash[:notice] = I18n.t("setup.create.success", scope: "decidim.secure_elections.admin")
              redirect_to election_monitor_path(election)
            end

            on(:invalid) do
              flash.now[:alert] = I18n.t("setup.create.invalid", scope: "decidim.secure_elections.admin")
              render action: "show", status: :unprocessable_content
            end
          end
        end
      end
    end
  end
end
