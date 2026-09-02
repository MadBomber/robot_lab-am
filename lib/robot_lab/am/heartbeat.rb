# frozen_string_literal: true

require "json"
require "time"
require "fileutils"

module RobotLab
  module Am
    # The daemon's liveness record (.robot_lab_am/heartbeat.json), rewritten
    # every tick — the "heartbeat row/line" ARCHITECTURE.md's Deployment model
    # section calls for, so `am status` can tell a live daemon from a stale
    # pid file left by a crash.
    class Heartbeat
      def initialize(path)
        @path = path
      end

      def beat(pid:, events_total:, last_inference_at:)
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, JSON.generate(
                            pid: pid,
                            updated_at: Time.now.utc.iso8601,
                            events_total: events_total,
                            last_inference_at: last_inference_at
                          ))
      end

      def read
        return nil unless File.exist?(@path)

        JSON.parse(File.read(@path))
      rescue JSON::ParserError
        nil
      end

      # Seconds since the last beat, or nil when there has been none.
      def age
        updated_at = read&.fetch("updated_at", nil)
        return nil unless updated_at

        (Time.now.utc - Time.parse(updated_at)).round
      end
    end
  end
end
