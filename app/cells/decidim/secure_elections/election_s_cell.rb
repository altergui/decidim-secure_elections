# frozen_string_literal: true

require "cell/partial"

module Decidim
  module SecureElections
    # The search (:s) card for an election.
    class ElectionSCell < Decidim::CardSCell
      private

      def metadata_cell
        "decidim/secure_elections/election_card_metadata"
      end
    end
  end
end
