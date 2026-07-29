# frozen_string_literal: true

module Decidim
  module SecureElections
    module Admin
      # Step 4 of the wizard: when voting happens.
      #
      # Two decisions. The election either starts the moment it reaches the
      # blockchain — which is stored as a NULL `start_time`, not as "now"
      # (ARCHITECTURE §2.3) — or at a moment the admin picks. The end time is
      # always required: upstream refuses a process without one, and an election
      # that never closes can never be tallied.
      class ElectionCalendarForm < Decidim::Form
        mimic :election

        # A blank `start_time` is not an omission: the process then starts the
        # moment it is published on chain.
        attribute :start_immediately, Boolean, default: true
        attribute :start_time, Decidim::Attributes::TimeWithZone
        attribute :end_time, Decidim::Attributes::TimeWithZone

        validates :end_time, presence: true
        validates :start_time, presence: true, unless: :start_immediately?

        # Both comparisons are hand-rolled rather than left to the `date:`
        # validator. Its message interpolates the raw restriction, which reached
        # the admin as "must be after Mon, 27 Jul 2026 21:54:36 +0000" — a
        # timestamp in a format that appears nowhere else in Decidim, in a time
        # zone the admin never chose. The wording below says what is wrong and
        # prints the moment the same way every other date on the screen is
        # printed, in the organization's own zone.
        validate :start_time_before_end_time
        validate :start_time_in_the_future
        validate :end_time_in_the_future

        def map_model(election)
          self.start_immediately = election.start_time.blank?
        end

        def election
          @election ||= context[:election]
        end

        def editable?
          election.nil? || election.editable?
        end

        def start_immediately?
          start_immediately.present?
        end

        # The value that must be persisted: "start immediately" is stored as
        # NULL, not as "now".
        def effective_start_time
          start_immediately? ? nil : start_time
        end

        private

        def start_time_before_end_time
          return if start_immediately?
          return if start_time.blank? || end_time.blank?
          return if start_time < end_time

          errors.add(:start_time, :not_before_end_time, end_time: formatted(end_time))
        end

        # A start time in the past is a typo, and it used to be accepted in
        # silence: the schedule saved, the publish checklist reported every item
        # done, and "what will be published" printed a start in 2020 without a
        # word about it — right up to the button that spends real tokens.
        #
        # It is only a mistake while the election can still be edited, for the
        # same reason the end time is. An election already on chain legitimately
        # has a start in the past, and re-validating one would make an existing
        # record unsaveable.
        #
        # The message points at "start immediately" because upstream would have
        # arrived there anyway, without telling anybody. `PublishElectionJob`
        # sends `startDate` verbatim when it is present (ARCHITECTURE §2.3), and
        # the SaaS backend accepts a past one: `electionStartDuration`
        # (`account/process.go`) only honours a start that is `After(time.Now())`
        # and otherwise emits `StartTime = 0` — "open at the mined block" — with
        # the duration measured from now to `endDate`. Publish then persists
        # `time.Now()` as the start. So a typo'd year is not refused on chain;
        # it opens the election immediately and leaves Decidim displaying a
        # start time the election never had. Saying that is more use than
        # refusing with "is invalid".
        def start_time_in_the_future
          return if start_immediately?
          return if start_time.blank? || !editable?
          return if start_time > Time.current

          errors.add(:start_time, :not_in_the_future, now: formatted(Time.current))
        end

        # An end time in the past is only a mistake while the election can still
        # be edited. Once it is on chain the record is read-only anyway.
        def end_time_in_the_future
          return if end_time.blank? || !editable?
          return if end_time > Time.current

          errors.add(:end_time, :not_in_the_future, now: formatted(Time.current))
        end

        # The format every other date in this admin is rendered in. `Time.zone`
        # is the organization's, set by Decidim for the request.
        def formatted(time)
          I18n.l(time.in_time_zone, format: :decidim_short)
        end
      end
    end
  end
end
