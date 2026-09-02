# frozen_string_literal: true

require "test_helper"

module RobotLab
  module Am
    class EventTest < Minitest::Test
      def test_to_h_json_includes_all_fields
        event = Event.new(timestamp: "2026-09-01T00:00:00Z", repo: "/repo", source: "git",
                          kind: "commit", summary: "abc1234 fix bug")

        assert_equal(
          { timestamp: "2026-09-01T00:00:00Z", repo: "/repo", source: "git", kind: "commit",
            summary: "abc1234 fix bug" },
          event.to_h_json
        )
      end

      def test_fingerprint_includes_timestamp_for_most_kinds
        base = { repo: "/repo", source: "terminal", kind: "command", summary: "rake test" }
        one = Event.new(timestamp: "2026-09-01T00:00:00Z", **base)
        two = Event.new(timestamp: "2026-09-01T00:00:05Z", **base)

        refute_equal one.fingerprint, two.fingerprint
        assert_equal one.fingerprint, Event.new(timestamp: "2026-09-01T00:00:00Z", **base).fingerprint
      end

      def test_fingerprint_ignores_timestamp_for_wip_events
        base = { repo: "/repo", source: "git", kind: "wip", summary: "Uncommitted changes:\nM lib/a.rb" }
        one = Event.new(timestamp: "2026-09-01T00:00:00Z", **base)
        two = Event.new(timestamp: "2026-09-01T00:05:00Z", **base)

        assert_equal one.fingerprint, two.fingerprint
        refute_equal one.fingerprint, one.with(summary: "Uncommitted changes:\nM lib/b.rb").fingerprint
      end
    end
  end
end
