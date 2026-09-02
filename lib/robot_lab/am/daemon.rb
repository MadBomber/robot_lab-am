# frozen_string_literal: true

require "time"

module RobotLab
  module Am
    # The continuous activity-monitor loop for one repo (ARCHITECTURE.md's
    # Deployment model): poll the watchers, append new events, and re-infer
    # the current intent on a debounced cadence.
    #
    # Cadence (resolves ARCHITECTURE.md open question 1): inference runs only
    # when new events have arrived since the last inference, and at most once
    # per `debounce` seconds — never per keystroke-equivalent event. The first
    # activity after startup infers immediately.
    #
    # Every collaborator is injectable so #tick is testable in isolation with
    # no LLM, no signals, and no sleeping. Tunables (interval, debounce,
    # inference window) default from Am::Config when not passed explicitly.
    class Daemon
      # :reek:LongParameterList -- one keyword per collaborator is the price
      # of #tick being testable in isolation; defaults resolve lazily below.
      def initialize(repo:, config: nil, interval: nil, debounce: nil,
                     event_log: nil, collector: nil, inferrer: nil, intent_writer: nil,
                     pid_file: nil, heartbeat: nil)
        @repo = repo
        @config = config
        @interval = interval
        @debounce = debounce
        @event_log = event_log
        @collector = collector
        @inferrer = inferrer
        @intent_writer = intent_writer
        @pid_file = pid_file
        @heartbeat = heartbeat
        @stop = false
        @dirty = false
        @events_total = 0
        @last_inference_at = nil
      end

      def run
        pid_file.write
        trap_signals
        until @stop
          tick
          wait
        end
      ensure
        pid_file.delete
      end

      def stop!
        @stop = true
      end

      # One poll cycle. Public so tests (and future callers) can drive the
      # loop without running it.
      def tick(now: Time.now)
        new_events = collector.collect_new
        @events_total += new_events.size
        @dirty = true unless new_events.empty?
        beat # before inference — a slow LLM call must not make a live daemon look dead
        return unless infer_due?(now)

        infer(now)
        beat
      end

      private

      def state_path(file)
        File.join(@repo, ".robot_lab_am", file)
      end

      def config    = @config ||= Am.config
      def interval  = @interval || config.interval
      def debounce  = @debounce || config.debounce

      def event_log = @event_log ||= EventLog.new(state_path("events.jsonl"))
      def collector = @collector ||= Collector.new(repo: @repo, event_log: event_log, config: config)
      def inferrer = @inferrer ||= Inferrer.new(config: config)
      def intent_writer = @intent_writer ||= IntentWriter.new(repo: @repo)
      def pid_file = @pid_file ||= PidFile.new(state_path("daemon.pid"))
      def heartbeat = @heartbeat ||= Heartbeat.new(state_path("heartbeat.json"))

      def beat
        heartbeat.beat(pid: Process.pid, events_total: @events_total,
                       last_inference_at: @last_inference_at&.utc&.iso8601)
      end

      def infer_due?(now)
        @dirty && (@last_inference_at.nil? || now - @last_inference_at >= debounce)
      end

      # A failed inference (LLM server down, malformed response) must not kill
      # the daemon; leaving @dirty set retries it once the next debounce
      # window opens, and stamping @last_inference_at anyway is what spaces
      # those retries out.
      def infer(now)
        window = event_log.all.last(config.inference_window)
        intent_writer.write(inferrer.infer(window, repo: @repo))
        @dirty = false
      rescue StandardError => e
        warn "[robot_lab-am] inference failed: #{e.class}: #{e.message}"
      ensure
        @last_inference_at = now
      end

      def wait
        sleep(interval) unless @stop
      end

      def trap_signals
        %w[TERM INT].each { |signal| Signal.trap(signal) { @stop = true } }
      end
    end
  end
end
