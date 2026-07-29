# frozen_string_literal: true

module Decidim
  module SecureElections
    module Admin
      # The irreversible step: hands the election over to the blockchain.
      #
      # The command itself performs **no** API call — it records the intent,
      # flips the election to `publishing` and enqueues
      # `Decidim::SecureElections::PublishElectionJob`. Every SaaS interaction lives in
      # that job (ARCHITECTURE §0.5).
      class SetupElection < Decidim::Command
        def initialize(form, current_user)
          @form = form
          @current_user = current_user
        end

        def call
          return broadcast(:invalid) if form.invalid?

          transaction do
            Decidim.traceability.perform_action!(
              :setup,
              election,
              current_user,
              visibility: "all"
            ) do
              election.update!(
                status: "publishing",
                results_cache: election.results_cache.to_h.except("error")
              )
              election
            end
          end

          # Enqueued outside the transaction so the worker cannot observe a row
          # that has not been committed yet.
          Decidim::SecureElections::PublishElectionJob.perform_later(election.id)

          broadcast(:ok, election)
        end

        private

        attr_reader :form, :current_user

        delegate :election, to: :form
      end
    end
  end
end
