# frozen_string_literal: true

require "cell/partial"

module Decidim
  module SecureElections
    # The list (:l) card for an election.
    class ElectionLCell < Decidim::CardLCell
      private

      def has_description?
        true
      end

      def metadata_cell
        "decidim/secure_elections/election_card_metadata"
      end
    end
  end
end
