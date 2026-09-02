# frozen_string_literal: true

require "fileutils"

module RobotLab
  module Am
    # Process management behind `am start|stop|status`: forks and detaches the
    # Daemon, tears it down with SIGTERM, and reports liveness from the pid
    # file plus the heartbeat. Methods return a human-readable message on
    # success and raise Am::Error on failure — the CLI turns those into
    # stdout/exit codes.
    #
    # :reek:RepeatedConditional -- daemon liveness (@pid_file.alive?) is
    # deliberately re-checked at each lifecycle boundary (start guard, stop,
    # status); caching it would defeat the point.
    class DaemonController
      START_TIMEOUT_SECONDS = 10
      STOP_TIMEOUT_SECONDS = 10

      def initialize(repo:, interval: nil, debounce: nil,
                     daemon_factory: nil, spawner: nil)
        @repo = repo
        @interval = interval
        @debounce = debounce
        @pid_file = PidFile.new(File.join(state_dir, "daemon.pid"))
        @heartbeat = Heartbeat.new(File.join(state_dir, "heartbeat.json"))
        @daemon_factory = daemon_factory
        @spawner = spawner
      end

      # :reek:BooleanParameter :reek:ControlParameter -- mirrors the CLI's
      # --foreground flag; both paths share the already-running guard.
      def start(foreground: false)
        raise Error, "daemon already running for #{@repo} (pid #{@pid_file.read})" if @pid_file.alive?

        @pid_file.delete
        return run_foreground if foreground

        run_background
      end

      def stop
        pid = @pid_file.read
        raise Error, "daemon not running for #{@repo}" unless pid

        unless @pid_file.alive?
          @pid_file.delete
          raise Error, "daemon not running for #{@repo} (removed stale pid file for pid #{pid})"
        end

        Process.kill("TERM", pid)
        wait_until(STOP_TIMEOUT_SECONDS, "daemon (pid #{pid}) did not exit within #{STOP_TIMEOUT_SECONDS}s") do
          !@pid_file.alive?
        end
        "stopped daemon for #{@repo} (pid #{pid})"
      end

      def status
        unless @pid_file.alive?
          suffix = @pid_file.exist? ? " (stale pid file: #{@pid_file.read})" : ""
          raise Error, "daemon not running for #{@repo}#{suffix}"
        end

        ["daemon running for #{@repo} (pid #{@pid_file.read})", *heartbeat_lines].join("\n")
      end

      private

      def daemon_factory = @daemon_factory ||= method(:build_daemon)
      def spawner = @spawner ||= method(:spawn_daemon)

      def state_dir
        File.join(@repo, ".robot_lab_am")
      end

      def log_path
        File.join(state_dir, "daemon.log")
      end

      # nil interval/debounce fall through to the Daemon's Am::Config lookup.
      def build_daemon
        Daemon.new(repo: @repo, interval: @interval, debounce: @debounce)
      end

      def run_foreground
        daemon_factory.call.run
        "daemon for #{@repo} exited"
      end

      def run_background
        child = spawner.call
        Process.detach(child)
        wait_until(START_TIMEOUT_SECONDS, "daemon did not start within #{START_TIMEOUT_SECONDS}s — see #{log_path}") do
          @pid_file.alive?
        end
        "started daemon for #{@repo} (pid #{@pid_file.read}), logging to #{log_path}"
      end

      # The double fork: the forked child detaches from the terminal via
      # Process.daemon, then runs the loop. exit! (not exit) so the child
      # never runs at_exit hooks inherited from the parent process.
      def spawn_daemon
        fork do
          Process.daemon(true)
          redirect_output
          exit!(run_daemon_safely)
        end
      end

      # Exit status for the daemonized child — 0 for a clean stop, 1 for a
      # crash, with the crash recorded in the log file.
      # :reek:FeatureEnvy -- formatting the caught exception for the log
      # inherently reads `e` more than self.
      def run_daemon_safely
        daemon_factory.call.run
        0
      rescue StandardError => e
        warn "[robot_lab-am] daemon crashed: #{e.class}: #{e.message}"
        warn e.backtrace.join("\n") if e.backtrace
        1
      end

      def redirect_output
        FileUtils.mkdir_p(File.dirname(log_path))
        $stdout.reopen(log_path, "a")
        $stderr.reopen(log_path, "a")
        $stdout.sync = true
        $stderr.sync = true
      end

      def heartbeat_lines
        data = @heartbeat.read
        return [] unless data

        [
          "  heartbeat: #{@heartbeat.age}s ago",
          "  events logged since start: #{data['events_total']}",
          "  last inference: #{data['last_inference_at'] || 'never'}"
        ]
      end

      def wait_until(timeout, failure_message)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        until yield
          raise Error, failure_message if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

          sleep 0.1
        end
      end
    end
  end
end
