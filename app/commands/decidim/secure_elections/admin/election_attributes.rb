# frozen_string_literal: true

module Decidim
  module SecureElections
    module Admin
      # The election columns the **details** step writes, shared by
      # `CreateElection` and `UpdateElection`.
      #
      # Deliberately narrow. The schedule is written by
      # `UpdateElectionCalendar`, the ballot by `UpdateElectionQuestions` and
      # the census by `UpdateElectionCensus`. Each step owns its own columns, so
      # a stale form left open on one step can never quietly undo what was saved
      # on another.
      module ElectionAttributes
        extend ActiveSupport::Concern

        private

        def election_attributes
          {
            title: parsed_title,
            description: parsed_description,
            stream_uri: form.stream_uri
          }
        end

        def parsed_title
          Decidim::ContentProcessor.parse(form.title, current_organization: form.current_organization).rewrite
        end

        def parsed_description
          Decidim::ContentProcessor.parse_with_processor(:inline_images, form.description, current_organization: form.current_organization).rewrite
        end
      end
    end
  end
end
