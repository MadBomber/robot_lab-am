# frozen_string_literal: true

require "test_helper"
require "json"

module RobotLab
  module Am
    module Watchers
      class ClaudeWatcherTest < Minitest::Test
        def test_events_empty_when_no_matching_project_dir
          with_tmp_dir do |dir|
            watcher = ClaudeWatcher.new(repo: dir, projects_dir: File.join(dir, "projects"))
            assert_empty watcher.events
          end
        end

        def test_events_extracts_only_human_text_messages
          with_tmp_dir do |dir|
            repo = File.join(dir, "myrepo")
            Dir.mkdir(repo)
            projects_dir = File.join(dir, "projects")
            slug_dir = File.join(projects_dir, repo.gsub(/[^a-zA-Z0-9]/, "-"))
            Dir.mkdir(projects_dir)
            Dir.mkdir(slug_dir)

            File.write(File.join(slug_dir, "session.jsonl"), transcript_lines)

            events = ClaudeWatcher.new(repo: repo, projects_dir: projects_dir).events

            assert_equal 1, events.size
            assert_equal "claude_code", events.first.source
            assert_equal "user_message", events.first.kind
            assert_equal "let's build the activity monitor", events.first.summary
          end
        end

        private

        def transcript_lines
          [
            { type: "user", timestamp: "t1", message: { role: "user", content: "let's build the activity monitor" } },
            { type: "user", timestamp: "t2",
              message: { role: "user", content: [{ type: "tool_result", content: "ok" }] } },
            { type: "assistant", timestamp: "t3",
              message: { role: "assistant", content: [{ type: "text", text: "sure, on it" }] } }
          ].map { |h| JSON.generate(h) }.join("\n") << "\n"
        end
      end
    end
  end
end
