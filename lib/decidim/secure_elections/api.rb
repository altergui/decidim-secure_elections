# frozen_string_literal: true

module Decidim
  module SecureElections
    # GraphQL types for the Vocdoni component.
    #
    # They are autoloaded rather than required so that the schema classes are
    # only built when the API is actually used, and so that `component.rb` can
    # name `Decidim::SecureElections::SecureElectionsElectionsType` at registration time.
    #
    # Names are prefixed because GraphQL type names are global to the schema:
    # `Decidim::Forms::QuestionType` already claims `Question`.
    autoload :SecureElectionsElectionsType, "decidim/api/secure_elections_elections_type"
    autoload :SecureElectionsElectionType, "decidim/api/secure_elections_election_type"
    autoload :SecureElectionsQuestionType, "decidim/api/secure_elections_question_type"
    autoload :SecureElectionsAnswerType, "decidim/api/secure_elections_answer_type"
  end
end
