# frozen_string_literal: true

module RobotLab
  module Am
    # Entry point for the `am` executable.
    #
    # `snapshot` is the one working command: a one-shot collect + infer +
    # write, run directly rather than through the daemon described in
    # ARCHITECTURE.md. `start`/`stop`/`status` are that daemon's future
    # interface — recognized but not implemented yet, so the CLI shape is
    # settled before the long-running behavior is.
    class CLI
      DAEMON_COMMANDS = %w[start stop status].freeze
      COMMANDS = (DAEMON_COMMANDS + %w[snapshot]).freeze

      def self.run(argv = ARGV)
        new.run(argv)
      end

      def run(argv)
        command = argv.first
        return puts("am #{VERSION}") if %w[--version -v].include?(command)
        return puts(usage) if command.nil? || %w[--help -h].include?(command)
        return run_snapshot(argv[1..]) if command == "snapshot"

        run_daemon_command(command)
      end

      private

      def run_daemon_command(command)
        unless DAEMON_COMMANDS.include?(command)
          warn "Unknown command: #{command.inspect}"
          warn usage
          exit 1
        end

        warn "`am #{command}` is not implemented yet — robot_lab-am is still in the design " \
             "stage. See ARCHITECTURE.md."
        exit 1
      end

      def run_snapshot(args)
        repo = File.expand_path(repo_option(args) || Dir.pwd)

        events = collect_events(repo)
        EventLog.new(File.join(repo, ".robot_lab_am", "events.jsonl")).append_all(events)

        intent = Inferrer.new.infer(events, repo: repo)
        path   = IntentWriter.new(repo: repo).write(intent)

        report_snapshot(repo, events, path)
      end

      def collect_events(repo)
        [
          Watchers::GitWatcher.new(repo: repo),
          Watchers::ClaudeWatcher.new(repo: repo),
          Watchers::TerminalWatcher.new(repo: repo)
        ].flat_map(&:events)
      end

      def report_snapshot(repo, events, path)
        puts "Collected #{events.size} event(s) from #{repo}"
        puts "Wrote #{path}"
        puts ""
        puts File.read(path)
      end

      def repo_option(args)
        idx = args.index("--repo")
        return nil unless idx

        args[idx + 1]
      end

      def usage
        <<~USAGE
          Usage: am COMMAND

          Commands:
            snapshot [--repo PATH]  Collect recent git/terminal/Claude Code activity for
                                     PATH (default: current directory), infer the current
                                     goal, and write .robot_lab_am/current_intent.md
            start   Start the activity-monitor daemon for this repo (not implemented yet)
            stop    Stop the running daemon (not implemented yet)
            status  Show whether the daemon is running (not implemented yet)

          Options:
            -h, --help     Show this help
            -v, --version  Print version and exit
        USAGE
      end
    end
  end
end
