# frozen_string_literal: true

module Decidim
  module SecureElections
    # Notifies the followers of a participatory space that an election is open
    # for voting.
    #
    # Publish it with:
    #
    #   Decidim::EventsManager.publish(
    #     event: "decidim.events.secure_elections.election_published",
    #     event_class: Decidim::SecureElections::ElectionPublishedEvent,
    #     resource: election,
    #     followers: election.participatory_space.followers
    #   )
    #
    # The event name doubles as the i18n scope (see
    # `Decidim::Events::SimpleEvent#i18n_scope`), so it must stay in sync with
    # `decidim.events.secure_elections.election_published` in `config/locales/en.yml`.
    class ElectionPublishedEvent < Decidim::Events::SimpleEvent
      def resource_text
        translated_attribute(resource.description)
      end

      def button_text
        I18n.t("button_text", scope: "decidim.events.secure_elections.election_published")
      end

      def button_url
        resource_url
      end
    end
  end
end
