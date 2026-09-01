# frozen_string_literal: true

module RobotLab
  module Am
    module Watchers
      # Commands run in the repo, read from the global preexec log written
      # by ~/.bashrc__activity_monitor. That log spans every shell on the
      # machine (see ARCHITECTURE.md's Privacy & redaction section) — the
      # opt-in boundary is enforced here, at read time, by filtering to
      # lines whose cwd falls under this one watched repo root.
      class TerminalWatcher
        DEFAULT_LOG_PATH = File.expand_path("~/.activity_monitor/terminal_activity.log")

        def initialize(repo:, log_path: DEFAULT_LOG_PATH, limit: 50)
          @repo = File.expand_path(repo)
          @log_path = log_path
          @limit = limit
        end

        def events
          return [] unless File.exist?(@log_path)

          File.readlines(@log_path).filter_map { |line| command_event(line) }.last(@limit)
        end

        private

        def command_event(line)
          epoch, cwd, command = line.chomp.split("\t", 3)
          return nil unless epoch && cwd && command && in_scope?(cwd)

          Event.new(timestamp: Time.at(epoch.to_f).utc.iso8601, repo: @repo, source: "terminal",
                    kind: "command", summary: command)
        end

        def in_scope?(cwd)
          cwd == @repo || cwd.start_with?("#{@repo}/")
        end
      end
    end
  end
end
