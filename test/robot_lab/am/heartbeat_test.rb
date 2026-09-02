# frozen_string_literal: true

require "test_helper"

module RobotLab
  module Am
    class HeartbeatTest < Minitest::Test
      def test_beat_writes_readable_json
        with_tmp_dir do |dir|
          heartbeat = Heartbeat.new(File.join(dir, "nested", "heartbeat.json"))
          heartbeat.beat(pid: 42, events_total: 7, last_inference_at: "2026-09-01T00:00:00Z")

          data = heartbeat.read

          assert_equal 42, data["pid"]
          assert_equal 7, data["events_total"]
          assert_equal "2026-09-01T00:00:00Z", data["last_inference_at"]
          assert_match(/\d{4}-\d{2}-\d{2}T/, data["updated_at"])
        end
      end

      def test_read_returns_nil_for_missing_or_corrupt_file
        with_tmp_dir do |dir|
          path = File.join(dir, "heartbeat.json")
          heartbeat = Heartbeat.new(path)

          assert_nil heartbeat.read

          File.write(path, "{not json")
          assert_nil heartbeat.read
        end
      end

      def test_age_is_seconds_since_last_beat
        with_tmp_dir do |dir|
          heartbeat = Heartbeat.new(File.join(dir, "heartbeat.json"))

          assert_nil heartbeat.age

          heartbeat.beat(pid: 1, events_total: 0, last_inference_at: nil)
          assert_operator heartbeat.age, :<=, 1
        end
      end
    end
  end
end
