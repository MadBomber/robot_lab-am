# frozen_string_literal: true

module RobotLab
  module Am
    # One collection pass over all three watchers: redacts each event, drops
    # anything already in the event log (by Event#fingerprint), and appends
    # what's genuinely new. Both the one-shot `am snapshot` and every daemon
    # tick go through here, so repeated runs never duplicate log lines.
    class Collector
      def initialize(repo:, event_log:, watchers: nil, config: nil)
        @repo = repo
        @event_log = event_log
        @watchers = watchers
        @config = config
      end

      # Returns the new events, already redacted and appended to the log.
      def collect_new
        fresh = watchers.flat_map(&:events)
                        .map { |event| Redactor.redact_event(event) }
                        .reject { |event| seen.include?(event.fingerprint) }
        fresh.each do |event|
          @event_log.append(event)
          seen << event.fingerprint
        end
        fresh
      end

      private

      # Seeded once from the existing log so a restart doesn't re-append
      # history; maintained incrementally after that.
      def seen
        @seen ||= @event_log.all.to_set(&:fingerprint)
      end

      def config = @config ||= Am.config

      def watchers
        @watchers ||= [
          Watchers::GitWatcher.new(repo: @repo),
          Watchers::ClaudeWatcher.new(repo: @repo),
          Watchers::TerminalWatcher.new(repo: @repo, log_path: config.terminal_log)
        ]
      end
    end
  end
end
