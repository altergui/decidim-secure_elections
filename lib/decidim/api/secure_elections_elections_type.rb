# frozen_string_literal: true

module Decidim
  module SecureElections
    # The component query type, named by `component.query_type` in
    # `lib/decidim/secure_elections/component.rb`.
    #
    # Elections are public objects — who ran, when, with which questions and
    # with which result — so they belong in the API. Nothing about the census
    # configuration or about the module's credentials is reachable from here.
    class SecureElectionsElectionsType < Decidim::Core::ComponentType
      graphql_name "VocdoniElections"
      description "A secure elections component of a participatory space."

      field :election,
            Decidim::SecureElections::SecureElectionsElectionType,
            "A single election of this component",
            null: true do
        argument :id, GraphQL::Types::ID, "The id of the election", required: true
      end

      field :elections,
            Decidim::SecureElections::SecureElectionsElectionType.connection_type,
            "A collection of elections",
            null: true,
            connection: true

      def elections
        Decidim::SecureElections::Election.where(component: object).published.includes(:component)
      end

      def election(id:)
        Decidim::Core::ComponentFinderBase
          .new(model_class: Decidim::SecureElections::Election)
          .call(object, { id: }, context)
      end
    end
  end
end
