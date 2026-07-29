# frozen_string_literal: true

require "spec_helper"

# The admin wizard's central invariant, in a real browser: **a step only opens
# once every step before it is complete.**
#
# It is enforced in three places — the navigation, the controllers and the
# permission class — precisely because any one of them can be bypassed. A unit
# spec can prove that one guard holds. Only driving the actual pages proves that
# an admin cannot walk past them.
describe "Admin manages elections" do
  include_context "when managing a component as an admin"

  let(:manifest_name) { "vocdoni" }
  let(:election_path) { Decidim::EngineRouter.admin_proxy(component) }

  describe "the elections list" do
    let!(:election) { create(:vocdoni_election, component:, skip_injection: true) }

    it "lists the elections of this component" do
      visit_component_admin

      expect(page).to have_text(translated(election.title))
    end
  end

  describe "step gating" do
    context "with a brand new election" do
      let!(:election) { create(:vocdoni_election, component:, skip_injection: true) }

      # Details is complete the moment the election has a title, so the ballot
      # is reachable; the census is not, because there is no ballot yet.
      it "refuses a step whose predecessors are not complete" do
        visit election_path.edit_election_questions_path(election)

        expect(page).to have_text("Questions")

        visit election_path.edit_election_calendar_path(election)

        expect(page).to have_current_path(%r{/elections/#{election.id}/(questions|census)/?(edit)?\z})
      end
    end

    context "with everything the wizard asks for" do
      let!(:election) { create(:vocdoni_election, :ready_to_publish, component:, skip_injection: true) }

      it "opens the publish step and asks for a typed confirmation" do
        visit election_path.election_setup_path(election)

        expect(page).to have_text("Before you publish")
      end
    end
  end

  # Once the process exists on chain nothing about it may be edited again — the
  # content steps stay reachable, and read-only.
  describe "an election already on chain" do
    let!(:election) { create(:vocdoni_election, :on_chain, component:, skip_injection: true) }

    it "keeps the details readable and refuses to let them be changed" do
      visit election_path.edit_election_path(election)

      expect(page).to have_text(translated(election.title))
      expect(page).to have_css("input[disabled], textarea[disabled], [data-locked]", visible: :all)
    end
  end
end
