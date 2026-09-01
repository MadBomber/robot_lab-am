# frozen_string_literal: true

require "test_helper"

module RobotLab
  module Am
    class InferrerTest < Minitest::Test
      SAMPLE_EVENT = Event.new(timestamp: "2026-09-01T00:00:00Z", repo: "/repo", source: "git",
                               kind: "commit", summary: "abc1234 add feature")

      def test_defaults_target_a_local_lm_studio_model
        assert_equal :openai, Inferrer::DEFAULT_PROVIDER
        assert_equal "qwen/qwen3.8-27b", Inferrer::DEFAULT_MODEL
        assert_equal "http://localhost:1234/v1", Inferrer::DEFAULT_API_BASE
      end

      def test_infer_returns_empty_intent_without_calling_robot_when_no_events
        robot = FakeRobot.new(nil)
        def robot.run(_prompt) = raise("should not be called")

        intent = Inferrer.new(robot: robot).infer([], repo: "/repo")

        assert_equal "No recent activity detected.", intent.goal
        assert_equal "low", intent.confidence
      end

      def test_infer_parses_well_formed_yaml_response
        robot = FakeRobot.new(<<~YAML)
          goal: Building the activity monitor gem.
          confidence: high
          evidence:
            - abc1234 add feature
          open_questions:
            - inference cadence?
        YAML

        intent = Inferrer.new(robot: robot).infer([SAMPLE_EVENT], repo: "/repo")

        assert_equal "Building the activity monitor gem.", intent.goal
        assert_equal "high", intent.confidence
        assert_equal ["abc1234 add feature"], intent.evidence
        assert_equal ["inference cadence?"], intent.open_questions
        refute_nil intent.generated_at
      end

      def test_infer_falls_back_to_raw_text_on_malformed_yaml
        robot = FakeRobot.new("not yaml: [unterminated")

        intent = Inferrer.new(robot: robot).infer([SAMPLE_EVENT], repo: "/repo")

        assert_equal "not yaml: [unterminated", intent.goal
        assert_equal "unknown", intent.confidence
        assert_empty intent.evidence
      end

      def test_infer_strips_yaml_fenced_code_block
        robot = FakeRobot.new(<<~RESPONSE)
          ```yaml
          goal: Fenced goal.
          confidence: medium
          ```
        RESPONSE

        intent = Inferrer.new(robot: robot).infer([SAMPLE_EVENT], repo: "/repo")

        assert_equal "Fenced goal.", intent.goal
        assert_equal "medium", intent.confidence
      end
    end
  end
end
