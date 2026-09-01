# frozen_string_literal: true

require "test_helper"
require "open3"

module RobotLab
  module Am
    module Watchers
      class GitWatcherTest < Minitest::Test
        def test_events_include_commits_and_wip
          with_tmp_dir do |dir|
            init_repo(dir)
            File.write(File.join(dir, "README.md"), "hello")
            git(dir, "add", "README.md")
            git(dir, "commit", "-m", "initial commit")
            File.write(File.join(dir, "README.md"), "changed, uncommitted")

            events = GitWatcher.new(repo: dir).events

            commit = events.find { |e| e.kind == "commit" }
            wip    = events.find { |e| e.kind == "wip" }

            refute_nil commit
            assert_match(/initial commit/, commit.summary)
            assert_equal "git", commit.source

            refute_nil wip
            assert_match(/README.md/, wip.summary)
          end
        end

        def test_events_empty_for_non_git_directory
          with_tmp_dir do |dir|
            assert_empty GitWatcher.new(repo: dir).events
          end
        end

        private

        def init_repo(dir)
          git(dir, "init", "-q")
          git(dir, "config", "user.email", "test@example.com")
          git(dir, "config", "user.name", "Test")
        end

        def git(dir, *)
          Open3.capture3("git", *, chdir: dir)
        end
      end
    end
  end
end
