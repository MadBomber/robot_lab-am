# frozen_string_literal: true

require "test_helper"

module RobotLab
  module Am
    module Watchers
      class TerminalWatcherTest < Minitest::Test
        def test_events_empty_when_log_missing
          with_tmp_dir do |dir|
            watcher = TerminalWatcher.new(repo: dir, log_path: File.join(dir, "missing.log"))
            assert_empty watcher.events
          end
        end

        def test_events_filters_to_repo_and_parses_command
          with_tmp_dir do |dir|
            log_path = File.join(dir, "terminal_activity.log")
            other_dir = "/somewhere/else"
            File.write(log_path, [
              "1788216081.272367\t#{dir}\techo in-scope",
              "1788216082.000000\t#{other_dir}\techo out-of-scope",
              "1788216083.000000\t#{dir}/sub\techo nested-in-scope"
            ].join("\n") << "\n")

            events = TerminalWatcher.new(repo: dir, log_path: log_path).events

            assert_equal 2, events.size
            assert_equal(["echo in-scope", "echo nested-in-scope"], events.map(&:summary))
            assert(events.all? { |e| e.source == "terminal" && e.kind == "command" })
          end
        end
      end
    end
  end
end
