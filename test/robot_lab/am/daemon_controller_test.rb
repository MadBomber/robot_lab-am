# frozen_string_literal: true

require "test_helper"

module RobotLab
  module Am
    class DaemonControllerTest < Minitest::Test
      class FakeDaemon
        attr_reader :ran

        def run
          @ran = true
        end
      end

      def pid_path(dir)
        File.join(dir, ".robot_lab_am", "daemon.pid")
      end

      def test_start_refuses_when_daemon_already_running
        with_tmp_dir do |dir|
          PidFile.new(pid_path(dir)).write(Process.pid)
          controller = DaemonController.new(repo: dir)

          error = assert_raises(Error) { controller.start }
          assert_match(/already running/, error.message)
        end
      end

      def test_start_foreground_runs_the_daemon_in_process
        with_tmp_dir do |dir|
          daemon = FakeDaemon.new
          controller = DaemonController.new(repo: dir, daemon_factory: -> { daemon })

          message = controller.start(foreground: true)

          assert daemon.ran
          assert_match(/exited/, message)
        end
      end

      def test_start_clears_a_stale_pid_file_first
        with_tmp_dir do |dir|
          dead = Process.spawn("true")
          Process.wait(dead)
          PidFile.new(pid_path(dir)).write(dead)
          daemon = FakeDaemon.new
          controller = DaemonController.new(repo: dir, daemon_factory: -> { daemon })

          controller.start(foreground: true)

          assert daemon.ran
        end
      end

      def test_background_start_then_stop_round_trip
        with_tmp_dir do |dir|
          path = pid_path(dir)
          spawner = lambda do
            fork do
              PidFile.new(path).write
              sleep 30
              exit!(0)
            end
          end
          controller = DaemonController.new(repo: dir, spawner: spawner)

          start_message = controller.start
          assert_match(/started daemon for #{Regexp.escape(dir)} \(pid \d+\)/, start_message)
          assert PidFile.new(path).alive?

          stop_message = controller.stop
          assert_match(/stopped daemon/, stop_message)
          refute PidFile.new(path).alive?
        end
      end

      def test_stop_without_pid_file_raises_not_running
        with_tmp_dir do |dir|
          error = assert_raises(Error) { DaemonController.new(repo: dir).stop }
          assert_match(/not running/, error.message)
        end
      end

      def test_stop_with_stale_pid_file_raises_and_removes_it
        with_tmp_dir do |dir|
          dead = Process.spawn("true")
          Process.wait(dead)
          PidFile.new(pid_path(dir)).write(dead)

          error = assert_raises(Error) { DaemonController.new(repo: dir).stop }

          assert_match(/stale pid file/, error.message)
          refute_path_exists pid_path(dir)
        end
      end

      def test_status_reports_running_daemon_with_heartbeat_detail
        with_tmp_dir do |dir|
          PidFile.new(pid_path(dir)).write(Process.pid)
          Heartbeat.new(File.join(dir, ".robot_lab_am", "heartbeat.json"))
                   .beat(pid: Process.pid, events_total: 9, last_inference_at: "2026-09-01T00:00:00Z")

          status = DaemonController.new(repo: dir).status

          assert_match(/running .*pid #{Process.pid}/, status)
          assert_match(/heartbeat: \d+s ago/, status)
          assert_match(/events logged since start: 9/, status)
          assert_match(/last inference: 2026-09-01T00:00:00Z/, status)
        end
      end

      def test_status_running_without_heartbeat_still_reports
        with_tmp_dir do |dir|
          PidFile.new(pid_path(dir)).write(Process.pid)

          assert_match(/running/, DaemonController.new(repo: dir).status)
        end
      end

      def test_status_raises_when_not_running_and_mentions_stale_pid
        with_tmp_dir do |dir|
          error = assert_raises(Error) { DaemonController.new(repo: dir).status }
          assert_match(/not running/, error.message)

          dead = Process.spawn("true")
          Process.wait(dead)
          PidFile.new(pid_path(dir)).write(dead)
          error = assert_raises(Error) { DaemonController.new(repo: dir).status }
          assert_match(/stale pid file/, error.message)
        end
      end

      def test_run_daemon_safely_reports_a_crash_as_exit_status_one
        with_tmp_dir do |dir|
          controller = DaemonController.new(repo: dir, daemon_factory: -> { raise "boom" })

          status = nil
          _, err = capture_io { status = controller.send(:run_daemon_safely) }

          assert_equal 1, status
          assert_match(/daemon crashed.*boom/, err)
        end
      end

      def test_run_daemon_safely_returns_zero_on_clean_exit
        with_tmp_dir do |dir|
          controller = DaemonController.new(repo: dir, daemon_factory: -> { FakeDaemon.new })

          assert_equal 0, controller.send(:run_daemon_safely)
        end
      end
    end
  end
end
