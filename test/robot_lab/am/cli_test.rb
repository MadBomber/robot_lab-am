# frozen_string_literal: true

require "test_helper"

module RobotLab
  module Am
    class CLITest < Minitest::Test
      def test_version_flag_prints_version
        out, = capture_io { CLI.run(["--version"]) }
        assert_match(/am \d+\.\d+/, out)
      end

      def test_no_args_prints_usage
        out, = capture_io { CLI.run([]) }
        assert_match(/Usage: am COMMAND/, out)
      end

      def test_help_flag_prints_usage
        out, = capture_io { CLI.run(["--help"]) }
        assert_match(/Usage: am COMMAND/, out)
      end

      def test_unknown_command_exits_nonzero
        _, err = capture_io do
          assert_raises(SystemExit) { CLI.run(["bogus"]) }
        end
        assert_match(/Unknown command: "bogus"/, err)
      end

      def test_known_but_unimplemented_daemon_command_exits_nonzero
        CLI::DAEMON_COMMANDS.each do |command|
          _, err = capture_io do
            assert_raises(SystemExit) { CLI.run([command]) }
          end
          assert_match(/not implemented yet/, err)
        end
      end

      def test_snapshot_writes_empty_intent_for_repo_with_no_activity
        with_tmp_dir do |dir|
          out, = capture_io { CLI.run(["snapshot", "--repo", dir]) }

          assert_match(/Collected 0 event\(s\)/, out)
          assert_match(/No recent activity detected\./, out)
          assert_path_exists File.join(dir, ".robot_lab_am", "current_intent.md")
        end
      end

      def test_snapshot_defaults_repo_to_current_directory
        with_tmp_dir do |dir|
          Dir.chdir(dir) { capture_io { CLI.run(["snapshot"]) } }

          assert_path_exists File.join(dir, ".robot_lab_am", "current_intent.md")
        end
      end
    end
  end
end
