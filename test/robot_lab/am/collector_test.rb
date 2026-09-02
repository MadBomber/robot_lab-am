# frozen_string_literal: true

require "test_helper"

module RobotLab
  module Am
    class CollectorTest < Minitest::Test
      FakeWatcher = Struct.new(:events)

      def build_event(summary, kind: "command", timestamp: "2026-09-01T00:00:00Z")
        Event.new(timestamp: timestamp, repo: "/repo", source: "terminal", kind: kind, summary: summary)
      end

      def test_appends_new_events_and_returns_them
        with_tmp_dir do |dir|
          log = EventLog.new(File.join(dir, "events.jsonl"))
          watcher = FakeWatcher.new([build_event("rake test")])

          collected = Collector.new(repo: "/repo", event_log: log, watchers: [watcher]).collect_new

          assert_equal ["rake test"], collected.map(&:summary)
          assert_equal ["rake test"], log.all.map(&:summary)
        end
      end

      def test_skips_events_already_collected_this_run
        with_tmp_dir do |dir|
          log = EventLog.new(File.join(dir, "events.jsonl"))
          watcher = FakeWatcher.new([build_event("rake test")])
          collector = Collector.new(repo: "/repo", event_log: log, watchers: [watcher])

          collector.collect_new
          watcher.events = [build_event("rake test"), build_event("rubocop", timestamp: "2026-09-01T00:01:00Z")]
          second = collector.collect_new

          assert_equal ["rubocop"], second.map(&:summary)
          assert_equal ['rake test', 'rubocop'], log.all.map(&:summary)
        end
      end

      def test_seeds_seen_set_from_existing_log_across_restarts
        with_tmp_dir do |dir|
          log = EventLog.new(File.join(dir, "events.jsonl"))
          watcher = FakeWatcher.new([build_event("rake test")])
          Collector.new(repo: "/repo", event_log: log, watchers: [watcher]).collect_new

          fresh_collector = Collector.new(repo: "/repo", event_log: log, watchers: [watcher])

          assert_empty fresh_collector.collect_new
          assert_equal 1, log.all.size
        end
      end

      def test_redacts_before_storing_and_deduping
        with_tmp_dir do |dir|
          log = EventLog.new(File.join(dir, "events.jsonl"))
          watcher = FakeWatcher.new([build_event("export MY_TOKEN=abc123")])
          collector = Collector.new(repo: "/repo", event_log: log, watchers: [watcher])

          collector.collect_new

          assert_equal ["export MY_TOKEN=[REDACTED]"], log.all.map(&:summary)
          # The same raw event dedupes against its stored, redacted form.
          assert_empty collector.collect_new
        end
      end

      def test_wip_events_dedupe_on_summary_despite_fresh_timestamps
        with_tmp_dir do |dir|
          log = EventLog.new(File.join(dir, "events.jsonl"))
          wip = ->(time) { build_event("Uncommitted changes:\nM lib/a.rb", kind: "wip", timestamp: time) }
          watcher = FakeWatcher.new([wip.call("2026-09-01T00:00:00Z")])
          collector = Collector.new(repo: "/repo", event_log: log, watchers: [watcher])

          collector.collect_new
          watcher.events = [wip.call("2026-09-01T00:05:00Z")]

          assert_empty collector.collect_new
        end
      end

      def test_uses_real_watchers_by_default
        with_tmp_dir do |dir|
          log = EventLog.new(File.join(dir, "events.jsonl"))

          assert_empty Collector.new(repo: dir, event_log: log).collect_new
        end
      end
    end
  end
end
