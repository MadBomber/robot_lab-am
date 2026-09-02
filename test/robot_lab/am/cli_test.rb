# frozen_string_literal: true

require "test_helper"

module RobotLab
  module Am
    class CLITest < Minitest::Test
      class FakeController
        attr_reader :calls

        def initialize(status_error: nil)
          @calls = []
          @status_error = status_error
        end

        def start(foreground:)
          @calls << [:start, foreground]
          "started!"
        end

        def stop
          @calls << [:stop]
          "stopped!"
        end

        def status
          @calls << [:status]
          raise Error, @status_error if @status_error

          "running!"
        end
      end

      class FakeLaunchd
        attr_reader :installed, :uninstalled

        def label = "com.example.fake"

        def install
          @installed = true
          "/agents/fake.plist"
        end

        def uninstall
          @uninstalled = true
          "/agents/fake.plist"
        end
      end

      def build_cli(controller: FakeController.new, launchd: FakeLaunchd.new)
        @controller = controller
        @launchd = launchd
        @factory_options = nil
        CLI.new(controller_factory: lambda { |options|
                                      @factory_options = options
                                      controller
                                    },
                launchd_factory: ->(_options) { launchd })
      end

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

      def test_start_dispatches_to_the_controller_with_parsed_options
        cli = build_cli
        out, = capture_io { cli.run(["start", "--repo", "/some/repo", "--interval", "5", "--debounce", "60"]) }

        assert_equal [[:start, false]], @controller.calls
        assert_equal "/some/repo", @factory_options[:repo]
        assert_equal 5, @factory_options[:interval]
        assert_equal 60, @factory_options[:debounce]
        assert_match(/started!/, out)
      end

      def test_start_foreground_flag_is_passed_through
        cli = build_cli
        capture_io { cli.run(["start", "--foreground"]) }

        assert_equal [[:start, true]], @controller.calls
      end

      def test_stop_and_status_dispatch_and_print_the_message
        cli = build_cli
        out, = capture_io { cli.run(["stop"]) }
        assert_match(/stopped!/, out)

        out, = capture_io { cli.run(["status"]) }
        assert_match(/running!/, out)
        assert_equal [[:stop], [:status]], @controller.calls
      end

      def test_status_failure_exits_nonzero_with_the_message
        cli = build_cli(controller: FakeController.new(status_error: "daemon not running"))

        _, err = capture_io do
          assert_raises(SystemExit) { cli.run(["status"]) }
        end
        assert_match(/daemon not running/, err)
      end

      def test_install_prints_launchctl_instructions
        cli = build_cli
        out, = capture_io { cli.run(["install"]) }

        assert @launchd.installed
        assert_match %r{Wrote /agents/fake\.plist}, out
        assert_match(%r{launchctl bootstrap gui/\d+ /agents/fake\.plist}, out)
        assert_match %r{launchctl bootout gui/\d+/com\.example\.fake}, out
      end

      def test_uninstall_prints_removal_and_bootout_instructions
        cli = build_cli
        out, = capture_io { cli.run(["uninstall"]) }

        assert @launchd.uninstalled
        assert_match %r{Removed /agents/fake\.plist}, out
        assert_match %r{launchctl bootout gui/\d+/com\.example\.fake}, out
      end

      def test_unknown_option_exits_nonzero
        _, err = capture_io do
          assert_raises(SystemExit) { build_cli.run(["start", "--bogus"]) }
        end
        assert_match(/Unknown option: "--bogus"/, err)
      end

      def test_option_missing_value_exits_nonzero
        _, err = capture_io do
          assert_raises(SystemExit) { build_cli.run(["start", "--repo"]) }
        end
        assert_match(/--repo requires a value/, err)
      end

      def test_non_integer_interval_exits_nonzero
        _, err = capture_io do
          assert_raises(SystemExit) { build_cli.run(["start", "--interval", "soon"]) }
        end
        assert_match(/--interval requires an integer/, err)
      end

      def test_snapshot_writes_empty_intent_for_repo_with_no_activity
        with_tmp_dir do |dir|
          out, = capture_io { CLI.run(["snapshot", "--repo", dir]) }

          assert_match(/Collected 0 new event\(s\)/, out)
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
