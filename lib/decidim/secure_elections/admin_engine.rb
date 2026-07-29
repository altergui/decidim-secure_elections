# frozen_string_literal: true

module Decidim
  module SecureElections
    # Admin engine: a five-step election wizard, then the live monitoring page.
    #
    # ```
    # 1. details   elections#edit            always reachable
    # 2. questions questions#edit            needs 1
    # 3. census    census#show               needs 1–2
    # 4. calendar  calendar#edit             needs 1–3
    # 5. publish   setup#show                needs 1–4, irreversible
    #    monitor   monitor#show              once the process is on chain
    # ```
    #
    # The order is a real prerequisite chain, enforced in three places: the
    # navigation disables what cannot be opened and says why, `WizardStep`
    # redirects a request for a locked step, and `Admin::Permissions` withholds
    # its grant. The rule itself lives on the model, in `Election#step_blocker`.
    #
    # Steps 1, 2 and 4 edit nested records without reloading: a question or an
    # option is added in the browser and the whole ballot is submitted at once. Once the process is on chain every content
    # step stays reachable but renders read-only — an admin has to be able to
    # see what was published.
    class AdminEngine < ::Rails::Engine
      isolate_namespace Decidim::SecureElections::Admin

      paths["db/migrate"] = nil
      paths["lib/tasks"] = nil

      routes do
        resources :elections do
          member do
            put :publish
            put :unpublish
            patch :soft_delete
            patch :restore
            # Draft autosave for the details step. Same save as `update`,
            # answered as JSON so the page never reloads under the admin's
            # fingers.
            patch :autosave
          end
          get :manage_trash, on: :collection

          # Step 2. Questions and their options on one screen, saved together —
          # adding an option costs no page load.
          resource :questions, only: [:edit, :update], controller: "questions" do
            patch :autosave
          end

          # Step 3. The census. `show` is the hub, `edit`/`update` is voter
          # authentication, the rest is the list of people. No route here
          # takes, or could take, a Vocdoni identifier: Decidim owns the
          # census and an administrator never sees an upstream id.
          resource :census, only: [:show, :edit, :update], controller: "census"

          get "census/members", to: "census#members", as: :census_members
          patch "census/members", to: "census#update_members", as: :census_update_members
          get "census/template", to: "census#template", as: :census_template
          post "census/import", to: "census#import", as: :census_import
          post "census/verifications", to: "census#import_from_verifications", as: :census_verifications
          delete "census/clear", to: "census#clear", as: :census_clear

          # Step 4. The schedule.
          resource :calendar, only: [:edit, :update], controller: "calendar"

          # Step 5 and beyond. `setup` pushes the process to Vocdoni;
          # `status` moves questions between ready/paused/ended.
          resource :setup, only: [:show, :create], controller: "setup"
          resource :monitor, only: [:show], controller: "monitor" do
            put :status
            get :refresh
          end
        end

        root to: "elections#index"
      end

      initializer "decidim_secure_elections_admin.menu" do
        Decidim.menu :admin_vocdoni_menu do |menu|
          election = @election
          next if election.blank?

          proxy = Decidim::EngineRouter.admin_proxy(election.component)

          Decidim::SecureElections::Election::NAV_STEPS.each do |step|
            path = case step
                   when :details then proxy.edit_election_path(election)
                   when :questions then proxy.edit_election_questions_path(election)
                   when :census then proxy.election_census_path(election)
                   when :calendar then proxy.edit_election_calendar_path(election)
                   when :publish then proxy.election_setup_path(election)
                   when :monitor then proxy.election_monitor_path(election)
                   end

            # A locked step keeps its place in the menu — an admin has to be
            # able to see what is still ahead of them — but leads nowhere.
            menu.add_item :"vocdoni_#{step}",
                          I18n.t(step, scope: "decidim.secure_elections.admin.menu"),
                          election.step_reachable?(step) ? path : "#",
                          icon_name: Decidim::SecureElections::Admin::ElectionsHelper::STEP_ICONS.fetch(step)
          end
        end
      end

      def load_seed
        nil
      end
    end
  end
end
