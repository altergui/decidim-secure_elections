# frozen_string_literal: true

require "cell/partial"

module Decidim
  module SecureElections
    # The grid (:g) card for an election.
    class ElectionGCell < Decidim::CardGCell
      def show
        render
      end

      private

      def show_description?
        true
      end

      def metadata_cell
        "decidim/secure_elections/election_card_metadata"
      end
    end
  end
end
