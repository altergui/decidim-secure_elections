# frozen_string_literal: true

module Decidim
  module SecureElections
    # Abstract controller every public controller of this engine inherits from.
    #
    # `Decidim::Components::BaseController` already resolves the current
    # component and participatory space, enforces `:read, :component` and sets
    # the breadcrumb, so there is very little left to do here.
    class ApplicationController < Decidim::Components::BaseController
      include Decidim::SecureElections::NeedsElection
    end
  end
end
