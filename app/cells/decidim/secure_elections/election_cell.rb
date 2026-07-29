# frozen_string_literal: true

module Decidim
  module SecureElections
    # Entry point for `resource.card = "decidim/secure_elections/election"`: dispatches to
    # the card size Decidim asked for.
    class ElectionCell < Decidim::ViewModel
      include Cell::ViewModel::Partial

      def show
        cell card_size, model, options
      end

      private

      def card_size
        case options[:size]
        when :s
          "decidim/secure_elections/election_s"
        when :g
          "decidim/secure_elections/election_g"
        else
          "decidim/secure_elections/election_l"
        end
      end
    end
  end
end
