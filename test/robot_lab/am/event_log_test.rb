# frozen_string_literal: true

require "test_helper"

module RobotLab
  module Am
    class EventLogTest < Minitest::Test
      def test_all_returns_empty_array_when_file_missing
        with_tmp_dir do |dir|
          log = EventLog.new(File.join(dir, "nope", "events.jsonl"))
          assert_empty log.all
        end
      end

      def test_append_and_all_round_trip
        with_tmp_dir do |dir|
          log = EventLog.new(File.join(dir, "events.jsonl"))
          event = Event.new(timestamp: "2026-09-01T00:00:00Z", repo: dir, source: "git",
                            kind: "commit", summary: "abc1234 fix bug")

          log.append(event)

          assert_equal [event], log.all
        end
      end

      def test_append_all_writes_multiple_events
        with_tmp_dir do |dir|
          log = EventLog.new(File.join(dir, "events.jsonl"))
          events = [
            Event.new(timestamp: "t1", repo: dir, source: "git", kind: "commit", summary: "one"),
            Event.new(timestamp: "t2", repo: dir, source: "git", kind: "commit", summary: "two")
          ]

          log.append_all(events)

          assert_equal events, log.all
        end
      end

      def test_all_skips_malformed_lines
        with_tmp_dir do |dir|
          path = File.join(dir, "events.jsonl")
          File.write(path, "not json\n")

          assert_empty EventLog.new(path).all
        end
      end
    end
  end
end
