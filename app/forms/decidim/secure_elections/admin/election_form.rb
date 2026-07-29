# frozen_string_literal: true

module Decidim
  module SecureElections
    module Admin
      # Step 1 of the wizard: what this election *is*.
      #
      # A title, a description, and optionally a video to show next to the
      # ballot. Nothing else — creating an election must not require an admin to
      # have already decided on the questions, the voters or the dates.
      #
      # The ballot lives in `ElectionQuestionsForm`, the schedule in
      # `ElectionCalendarForm`, and who may vote in `CensusForm`. Each is its
      # own step and its own screen; none of them can be opened before this one
      # is complete (`Election#step_blocker`).
      #
      # Nothing here talks to the Vocdoni API. The election only reaches the
      # blockchain through `SetupForm`, which is a separate, explicit and
      # irreversible act.
      class ElectionForm < Decidim::Form
        mimic :election

        include Decidim::TranslatableAttributes

        translatable_attribute :title, String
        translatable_attribute :description, Decidim::Attributes::RichText

        attribute :stream_uri, String

        validates :title, translatable_presence: true
        validate :stream_uri_is_a_url

        def map_model(election)
          self.stream_uri = election.stream_uri
        end

        def election
          @election ||= context[:election]
        end

        # Once the process exists on chain its payload is frozen upstream, so
        # the form must not pretend otherwise.
        def editable?
          election.nil? || election.editable?
        end

        private

        def stream_uri_is_a_url
          return if stream_uri.blank?

          uri = URI.parse(stream_uri)
          raise URI::InvalidURIError unless uri.is_a?(URI::HTTP) && uri.host.present?
        rescue URI::InvalidURIError
          errors.add(:stream_uri, :invalid)
        end
      end
    end
  end
end
