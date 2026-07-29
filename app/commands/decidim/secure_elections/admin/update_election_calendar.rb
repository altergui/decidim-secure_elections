# frozen_string_literal: true

module Decidim
  module SecureElections
    module Admin
      # Saves step 4 of the wizard: the schedule.
      #
      # "Start immediately" is persisted as a NULL `start_time`, never as the
      # current time — the process then opens the moment it reaches the chain
      # (ARCHITECTURE §2.3). Writing "now" instead would silently drift by however
      # long the publish job takes.
      class UpdateElectionCalendar < Decidim::Commands::UpdateResource
        private

        alias election resource

        def invalid?
          return true unless election.editable?

          form.invalid?
        end

        def attributes
          @attributes ||= {
            start_time: form.effective_start_time,
            end_time: form.end_time
          }
        end
      end
    end
  end
end
