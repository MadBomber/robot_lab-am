# frozen_string_literal: true

require "open3"

module RobotLab
  module Am
    module Watchers
      # Recent commits plus current uncommitted state, for one repo.
      # All subprocess calls use explicit argv arrays (no shell interpolation).
      class GitWatcher
        GIT_ENV = { "GIT_TERMINAL_PROMPT" => "0" }.freeze
        LOG_FORMAT = "%H%x09%aI%x09%s"

        def initialize(repo:, limit: 20)
          @repo = repo
          @limit = limit
        end

        def events
          commit_events + wip_events
        end

        private

        def commit_events
          out, _err, status = Open3.capture3(
            GIT_ENV, "git", "log", "-n", @limit.to_s, "--format=#{LOG_FORMAT}", chdir: @repo
          )
          return [] unless status.success?

          out.each_line.filter_map { |line| commit_event(line) }
        end

        def commit_event(line)
          sha, iso_time, subject = line.chomp.split("\t", 3)
          return nil unless sha && iso_time

          Event.new(timestamp: iso_time, repo: @repo, source: "git", kind: "commit",
                    summary: "#{sha[0, 7]} #{subject}")
        end

        def wip_events
          out, _err, status = Open3.capture3(GIT_ENV, "git", "status", "--short", chdir: @repo)
          return [] unless status.success? && !out.strip.empty?

          [Event.new(timestamp: Time.now.utc.iso8601, repo: @repo, source: "git", kind: "wip",
                     summary: "Uncommitted changes:\n#{out.strip}")]
        end
      end
    end
  end
end
