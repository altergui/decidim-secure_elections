# frozen_string_literal: true

module Decidim
  module SecureElections
    module Admin
      # The election list, the trash, and **step 1** of the wizard: the details.
      #
      # `new`/`create` and `edit`/`update` render and save the same, small form
      # — a title, a description and an optional video. That is all it takes to
      # bring an election into existence; the ballot, the census and the
      # schedule are steps of their own.
      #
      # The wizard is strict: `QuestionsController`, `CensusController`,
      # `CalendarController` and `SetupController` each refuse to open until
      # every step before them is complete. This one has no prerequisite beyond
      # the record existing, so it is always reachable — including after the
      # election is on chain, when it renders read-only.
      #
      # `autosave` is the same save answered as JSON, so the browser can keep
      # the draft up to date while the admin is still typing. Like every other
      # action here it never contacts the Vocdoni API (ARCHITECTURE §0.5).
      class ElectionsController < Admin::ApplicationController
        include Decidim::Admin::HasTrashableResources
        include Decidim::Admin::Filterable

        # Only the editing screens are part of the wizard: the index, the trash
        # and `create` exist before there is a step to be on.
        wizard_step :details, only: [:edit, :update, :autosave]

        helper_method :elections, :election

        def index
          enforce_permission_to :read, :election
        end

        # `resources :elections` exposes a canonical show route. There is no
        # separate "election page" in the admin, so it lands on the furthest
        # step the admin can actually work on — the monitor once the process is
        # on chain, the first unfinished step otherwise.
        def show
          enforce_permission_to :read, :election

          redirect_to secure_elections_step_path(election, election.furthest_reachable_step)
        end

        def new
          enforce_permission_to :create, :election

          @form = form(Decidim::SecureElections::Admin::ElectionForm).instance
        end

        def create
          enforce_permission_to :create, :election

          @form = form(Decidim::SecureElections::Admin::ElectionForm).from_params(params, current_component:)

          Decidim::SecureElections::Admin::CreateElection.call(@form) do
            on(:ok) do |election|
              flash[:notice] = I18n.t("elections.create.success", scope: "decidim.secure_elections.admin")
              # Straight on to the ballot: the details step is complete the
              # moment the record has a title.
              redirect_to secure_elections_step_path(election, :questions)
            end

            on(:invalid) do
              flash.now[:alert] = I18n.t("elections.create.invalid", scope: "decidim.secure_elections.admin")
              render action: "new", status: :unprocessable_content
            end
          end
        end

        def edit
          enforce_permission_to :read, :election

          @form = form(Decidim::SecureElections::Admin::ElectionForm).from_model(election, election:)
        end

        def update
          enforce_permission_to(:update, :election, election:)

          @form = form(Decidim::SecureElections::Admin::ElectionForm).from_params(params, current_component:, election:)

          Decidim::SecureElections::Admin::UpdateElection.call(@form, election) do
            on(:ok) do
              flash[:notice] = I18n.t("elections.update.success", scope: "decidim.secure_elections.admin")
              redirect_to next_step_path
            end

            on(:invalid) do
              flash.now[:alert] = I18n.t("elections.update.invalid", scope: "decidim.secure_elections.admin")
              render action: "edit", status: :unprocessable_content
            end
          end
        end

        # Draft autosave. Same command, same validations, no redirect: the
        # browser calls it periodically and on blur, so that a closed tab does
        # not cost an afternoon of work.
        def autosave
          # Asked without raising, so that a refusal can be answered in the
          # format the caller asked for. See `autosave_refused`.
          return autosave_refused unless allowed_to?(:update, :election, election:)

          @form = form(Decidim::SecureElections::Admin::ElectionForm).from_params(params, current_component:, election:)

          Decidim::SecureElections::Admin::UpdateElection.call(@form, election) do
            on(:ok) do
              render json: { saved: true, saved_at: Time.current.iso8601 }, status: :ok
            end

            on(:invalid) do
              render json: { saved: false, errors: @form.errors.full_messages }, status: :unprocessable_content
            end
          end
        end

        # Decidim visibility only — this makes the election's page reachable on
        # the public site. It writes nothing to the blockchain; that is the
        # setup step, and the two must never be mistaken for each other.
        def publish
          enforce_permission_to(:publish, :election, election:)

          Decidim::SecureElections::Admin::PublishElection.call(election, current_user) do
            on(:ok) do
              # A page nobody can vote on is the half of this that an admin gets
              # wrong, so an election that has not reached the chain says so
              # rather than leaving "it is live" to be assumed.
              # i18n-tasks-use t("decidim.secure_elections.admin.elections.publish.success")
              # i18n-tasks-use t("decidim.secure_elections.admin.elections.publish.success_not_on_chain")
              key = election.on_chain? ? "success" : "success_not_on_chain"
              flash[:notice] = I18n.t("elections.publish.#{key}", scope: "decidim.secure_elections.admin")
              redirect_to elections_path
            end

            on(:invalid) do
              flash[:alert] = I18n.t("elections.publish.invalid", scope: "decidim.secure_elections.admin")
              redirect_to elections_path
            end
          end
        end

        def unpublish
          enforce_permission_to(:unpublish, :election, election:)

          Decidim::SecureElections::Admin::UnpublishElection.call(election, current_user) do
            on(:ok) do
              flash[:notice] = I18n.t("elections.unpublish.success", scope: "decidim.secure_elections.admin")
              redirect_to elections_path
            end

            on(:invalid) do
              flash[:alert] = I18n.t("elections.unpublish.invalid", scope: "decidim.secure_elections.admin")
              redirect_to elections_path
            end
          end
        end

        private

        # After a successful save, move on — but only if the next step has
        # actually become reachable. Saving a title that is still blank in the
        # organization's language leaves the admin where they are rather than
        # bouncing them forward and straight back.
        def next_step_path
          election.reload
          return secure_elections_step_path(election, :questions) if election.step_reachable?(:questions)

          secure_elections_step_path(election, :details)
        end

        def elections
          @elections ||= filtered_collection
        end

        def election
          @election ||= collection.find(params.expect(:id))
        end

        def collection
          @collection ||= Decidim::SecureElections::Election.where(component: current_component)
        end

        # --- Decidim::Admin::Filterable -------------------------------------

        def base_query
          collection.order(created_at: :desc)
        end

        def search_field_predicate
          :search_text_cont
        end

        def filters
          [:with_any_state, :published_at_null]
        end

        def filters_with_values
          {
            with_any_state: %w(upcoming ongoing finished),
            published_at_null: [true, false]
          }
        end

        # --- Decidim::Admin::HasTrashableResources --------------------------

        def trashable_deleted_resource_type
          :election
        end

        def trashable_deleted_collection
          @trashable_deleted_collection ||= paginate(collection.only_deleted.deleted_at_desc)
        end

        def trashable_deleted_resource
          @trashable_deleted_resource ||= Decidim::SecureElections::Election.with_deleted.find_by(component: current_component, id: params[:id])
        end
      end
    end
  end
end
