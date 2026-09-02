# frozen_string_literal: true

require "test_helper"

module RobotLab
  module Am
    class DaemonTest < Minitest::Test
      FakeCollector = Struct.new(:batches) do
        def collect_new
          result = batches.shift
          result.respond_to?(:call) ? result.call : (result || [])
        end
      end

      class FakeInferrer
        attr_reader :calls

        def initialize(fail_times: 0)
          @calls = []
          @fail_times = fail_times
        end

        def infer(events, repo:)
          @calls << { events: events, repo: repo }
          raise "LLM unavailable" if (@fail_times -= 1) >= 0

          Intent.new(goal: "test goal", confidence: "high", evidence: [], open_questions: [],
                     generated_at: Time.now.utc.iso8601)
        end
      end

      FakeIntentWriter = Struct.new(:written) do
        def write(intent)
          (self.written ||= []) << intent
          "/fake/current_intent.md"
        end
      end

      def build_event(summary)
        Event.new(timestamp: "2026-09-01T00:00:00Z", repo: "/repo", source: "terminal",
                  kind: "command", summary: summary)
      end

      def build_daemon(dir, collector:, inferrer: FakeInferrer.new, writer: FakeIntentWriter.new,
                       debounce: 300, config: nil)
        @inferrer = inferrer
        @writer = writer
        @heartbeat = Heartbeat.new(File.join(dir, "heartbeat.json"))
        Daemon.new(repo: dir, interval: 0, debounce: debounce, config: config,
                   event_log: EventLog.new(File.join(dir, "events.jsonl")),
                   collector: collector, inferrer: inferrer, intent_writer: writer,
                   pid_file: PidFile.new(File.join(dir, "daemon.pid")), heartbeat: @heartbeat)
      end

      def test_tick_with_new_events_infers_immediately_and_beats_heartbeat
        with_tmp_dir do |dir|
          daemon = build_daemon(dir, collector: FakeCollector.new([[build_event("rake test")]]))

          daemon.tick(now: Time.at(1000))

          assert_equal 1, @inferrer.calls.size
          assert_equal dir, @inferrer.calls.first[:repo]
          assert_equal 1, @writer.written.size
          assert_equal 1, @heartbeat.read["events_total"]
          refute_nil @heartbeat.read["last_inference_at"]
        end
      end

      def test_default_collaborators_wire_up_from_the_repo_path_alone
        with_tmp_dir do |dir|
          Daemon.new(repo: dir).tick(now: Time.at(1000))

          heartbeat = Heartbeat.new(File.join(dir, ".robot_lab_am", "heartbeat.json")).read
          assert_equal 0, heartbeat["events_total"]
          assert_nil heartbeat["last_inference_at"]
        end
      end

      def test_tick_without_new_events_does_not_infer
        with_tmp_dir do |dir|
          daemon = build_daemon(dir, collector: FakeCollector.new([[]]))

          daemon.tick(now: Time.at(1000))

          assert_empty @inferrer.calls
          assert_nil @heartbeat.read["last_inference_at"]
        end
      end

      def test_inference_is_debounced_until_the_window_reopens
        with_tmp_dir do |dir|
          batches = [[build_event("one")], [build_event("two")], [], [build_event("three")]]
          daemon = build_daemon(dir, collector: FakeCollector.new(batches), debounce: 300)

          daemon.tick(now: Time.at(1000)) # infers: first activity
          daemon.tick(now: Time.at(1100)) # new events, but inside debounce window
          daemon.tick(now: Time.at(1400)) # window open, dirty from tick 2 -> infers
          daemon.tick(now: Time.at(1800)) # new events, window open again -> infers

          assert_equal 3, @inferrer.calls.size
        end
      end

      def test_no_inference_when_nothing_new_arrived_since_last_one
        with_tmp_dir do |dir|
          daemon = build_daemon(dir, collector: FakeCollector.new([[build_event("one")], [], []]), debounce: 0)

          daemon.tick(now: Time.at(1000))
          daemon.tick(now: Time.at(2000))
          daemon.tick(now: Time.at(3000))

          assert_equal 1, @inferrer.calls.size
        end
      end

      def test_inference_reads_a_bounded_window_from_the_event_log
        with_tmp_dir do |dir|
          window = Config.new.inference_window
          log = EventLog.new(File.join(dir, "events.jsonl"))
          (window + 10).times { |n| log.append(build_event("cmd #{n}")) }
          daemon = build_daemon(dir, collector: FakeCollector.new([[build_event("new")]]))

          daemon.tick(now: Time.at(1000))

          assert_equal window, @inferrer.calls.first[:events].size
        end
      end

      def test_tunables_come_from_config_when_not_passed_explicitly
        with_tmp_dir do |dir|
          batches = [[build_event("one")], [build_event("two")], [build_event("three")]]
          daemon = build_daemon(dir, collector: FakeCollector.new(batches), debounce: nil,
                                config: Config.new(interval: 1, debounce: 0, inference_window: 2))

          daemon.tick(now: Time.at(1000))
          daemon.tick(now: Time.at(1000)) # debounce 0 from config: every dirty tick infers

          assert_equal 2, @inferrer.calls.size
        end
      end

      def test_failed_inference_warns_retries_after_debounce_and_keeps_the_daemon_alive
        with_tmp_dir do |dir|
          inferrer = FakeInferrer.new(fail_times: 1)
          daemon = build_daemon(dir, collector: FakeCollector.new([[build_event("one")], [], []]),
                                inferrer: inferrer, debounce: 300)

          _, err = capture_io do
            daemon.tick(now: Time.at(1000)) # fails, warns
            daemon.tick(now: Time.at(1100)) # still dirty, but debounced
            daemon.tick(now: Time.at(1400)) # retry succeeds
          end

          assert_match(/inference failed.*LLM unavailable/, err)
          assert_equal 2, inferrer.calls.size
          assert_equal 1, @writer.written.size
        end
      end

      def test_heartbeat_beats_before_inference_so_a_slow_llm_call_never_looks_dead
        with_tmp_dir do |dir|
          heartbeat_path = File.join(dir, "heartbeat.json")
          beaten_before_inference = nil
          inferrer = Object.new
          inferrer.define_singleton_method(:infer) do |_events, repo:| # rubocop:disable Lint/UnusedBlockArgument
            beaten_before_inference = File.exist?(heartbeat_path)
            Intent.new(goal: "g", confidence: "low", evidence: [], open_questions: [],
                       generated_at: Time.now.utc.iso8601)
          end
          daemon = build_daemon(dir, collector: FakeCollector.new([[build_event("one")]]), inferrer: inferrer)

          daemon.tick(now: Time.at(1000))

          assert beaten_before_inference, "heartbeat should be written before inference starts"
          refute_nil @heartbeat.read["last_inference_at"], "and again after inference completes"
        end
      end

      def test_run_writes_pid_file_loops_until_stopped_and_cleans_up
        with_tmp_dir do |dir|
          old_term = Signal.trap("TERM", "DEFAULT")
          old_int  = Signal.trap("INT", "DEFAULT")

          pid_path = File.join(dir, "daemon.pid")
          daemon = nil
          in_run_pid = nil
          probe = lambda {
            in_run_pid = File.read(pid_path).to_i
            daemon.stop!
            []
          }
          daemon = build_daemon(dir, collector: FakeCollector.new([probe]))

          daemon.run

          assert_equal Process.pid, in_run_pid
          refute_path_exists pid_path
        ensure
          Signal.trap("TERM", old_term || "DEFAULT")
          Signal.trap("INT", old_int || "DEFAULT")
        end
      end
    end
  end
end
