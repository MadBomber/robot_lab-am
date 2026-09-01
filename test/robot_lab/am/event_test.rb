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
    end
  end
end
