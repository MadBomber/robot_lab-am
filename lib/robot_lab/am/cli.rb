# frozen_string_literal: true

module RobotLab
  module Am
    # Entry point for the `am` executable.
    #
    # `snapshot` is the one-shot collect + infer + write. `start`/`stop`/
    # `status` manage the continuous daemon (DaemonController), and
    # `install`/`uninstall` manage the launchd agent that supervises it.
    # Factories are injectable so tests can exercise dispatch without forking
    # processes or touching ~/Library.
    class CLI
      COMMANDS = %w[snapshot start stop status install uninstall].freeze

      def self.run(argv = ARGV)
        new.run(argv)
      end

      def initialize(controller_factory: nil, launchd_factory: nil)
        @controller_factory = controller_factory
        @launchd_factory = launchd_factory
      end

      # :reek:TooManyStatements -- the flag/guard/dispatch sequence reads
      # best as one method; each statement is a distinct early return.
      def run(argv)
        command = argv.first
        return puts("am #{VERSION}") if %w[--version -v].include?(command)
        return puts(usage) if command.nil? || %w[--help -h].include?(command)

        unless COMMANDS.include?(command)
          warn "Unknown command: #{command.inspect}"
          warn usage
          exit 1
        end

        dispatch(command, parse_options(argv[1..]))
      rescue Error => e
        warn e.message
        exit 1
      end

      private

      # :reek:ControlParameter :reek:DuplicateMethodCall -- a dispatcher is
      # controlled by its command by definition, and only one case branch
      # (hence one controller build) ever runs per invocation.
      def dispatch(command, options)
        case command
        when "snapshot"  then run_snapshot(options)
        when "start"     then puts controller(options).start(foreground: options[:foreground])
        when "stop"      then puts controller(options).stop
        when "status"    then puts controller(options).status
        when "install"   then run_install(options)
        when "uninstall" then run_uninstall(options)
        end
      end

      def controller_factory
        @controller_factory ||= ->(options) { DaemonController.new(**options.slice(:repo, :interval, :debounce)) }
      end

      def launchd_factory
        @launchd_factory ||= ->(options) { Launchd.new(**options.slice(:repo, :interval, :debounce)) }
      end

      def controller(options)
        controller_factory.call(options)
      end

      def config
        @config ||= Am.config
      end

      def run_snapshot(options)
        repo = options[:repo]
        event_log = EventLog.new(File.join(repo, ".robot_lab_am", "events.jsonl"))
        new_events = Collector.new(repo: repo, event_log: event_log, config: config).collect_new

        intent = Inferrer.new(config: config).infer(event_log.all.last(config.inference_window), repo: repo)
        path   = IntentWriter.new(repo: repo).write(intent)

        report_snapshot(repo, new_events, path)
      end

      def report_snapshot(repo, new_events, path)
        puts "Collected #{new_events.size} new event(s) from #{repo}"
        puts "Wrote #{path}"
        puts ""
        puts File.read(path)
      end

      def run_install(options)
        launchd = launchd_factory.call(options)
        path = launchd.install
        puts <<~MSG
          Wrote #{path}
          Load it now (and on every login) with:
            launchctl bootstrap gui/#{Process.uid} #{path}
          Unload it with:
            launchctl bootout gui/#{Process.uid}/#{launchd.label}
        MSG
      end

      def run_uninstall(options)
        launchd = launchd_factory.call(options)
        path = launchd.uninstall
        puts <<~MSG
          Removed #{path}
          If the agent was loaded, unload it with:
            launchctl bootout gui/#{Process.uid}/#{launchd.label}
        MSG
      end

      # :reek:FeatureEnvy :reek:TooManyStatements -- an option parser's whole
      # job is filling the options hash, one statement per flag.
      # interval/debounce stay nil unless flagged — downstream they fall
      # through to Am::Config (user config file / RLAM_* env vars).
      def parse_options(args)
        options = { repo: Dir.pwd, foreground: false, interval: nil, debounce: nil }
        args = args.dup
        until args.empty?
          arg = args.shift
          case arg
          when "--repo"       then options[:repo] = required_value(args, arg)
          when "--interval"   then options[:interval] = integer_value(args, arg)
          when "--debounce"   then options[:debounce] = integer_value(args, arg)
          when "--foreground" then options[:foreground] = true
          else raise Error, "Unknown option: #{arg.inspect}"
          end
        end
        options[:repo] = File.expand_path(options[:repo])
        options
      end

      # :reek:FeatureEnvy -- validating the shifted value is this method's
      # entire job.
      def required_value(args, flag)
        value = args.shift
        raise Error, "#{flag} requires a value" if value.nil? || value.start_with?("--")

        value
      end

      def integer_value(args, flag)
        Integer(required_value(args, flag))
      rescue ArgumentError
        raise Error, "#{flag} requires an integer value"
      end

      def usage
        <<~USAGE
          Usage: am COMMAND [options]

          Commands:
            snapshot   One-shot: collect new git/terminal/Claude Code activity, infer the
                       current goal, and write .robot_lab_am/current_intent.md
            start      Start the activity-monitor daemon for the repo
                       (--foreground to run in this terminal instead of detaching)
            stop       Stop the running daemon
            status     Show whether the daemon is running, with heartbeat detail
            install    Write a launchd agent plist so the daemon runs at login
            uninstall  Remove the launchd agent plist

          Options:
            --repo PATH    Repo to watch (default: current directory)
            --interval N   Seconds between daemon polls (currently: #{config.interval})
            --debounce N   Minimum seconds between inference runs (currently: #{config.debounce})
            --foreground   With start: run the daemon without detaching
            -h, --help     Show this help
            -v, --version  Print version and exit

          Configuration cascade (lowest to highest precedence): bundled
          defaults -> ~/.config/robot_lab_am/robot_lab_am.yml ->
          RLAM_* env vars -> the flags above.
        USAGE
      end
    end
  end
end
