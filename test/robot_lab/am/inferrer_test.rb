# frozen_string_literal: true

require "test_helper"

module RobotLab
  module Am
    class InferrerTest < Minitest::Test
      SAMPLE_EVENT = Event.new(timestamp: "2026-09-01T00:00:00Z", repo: "/repo", source: "git",
                               kind: "commit", summary: "abc1234 add feature")

      def test_defaults_target_a_local_lm_studio_model_via_config
        inferrer = Inferrer.new(config: Config.new)

        assert_equal :openai, inferrer.send(:provider)
        assert_equal "qwen/qwen3.8-27b", inferrer.send(:model)
        assert_equal "http://localhost:1234/v1", inferrer.send(:config).api_base
      end

      def test_keyword_overrides_beat_config
        inferrer = Inferrer.new(config: Config.new, model: "other-model", provider: :anthropic)

        assert_equal :anthropic, inferrer.send(:provider)
        assert_equal "other-model", inferrer.send(:model)
      end

      def test_llm_context_scopes_api_base_and_placeholder_key_for_local_openai
        saved = ENV.delete("OPENAI_API_KEY")
        inferrer = Inferrer.new(config: Config.new(api_base: "http://localhost:9999/v1"))

        context_config = inferrer.send(:llm_context).config

        assert_equal "http://localhost:9999/v1", context_config.openai_api_base
        assert_equal Inferrer::PLACEHOLDER_API_KEY, context_config.openai_api_key
        # the global RubyLLM config is untouched
        refute_equal "http://localhost:9999/v1", RubyLLM.config.openai_api_base
      ensure
        ENV["OPENAI_API_KEY"] = saved if saved
      end

      def test_api_key_cascade_config_then_provider_env_var
        saved = ENV.fetch("OPENAI_API_KEY", nil)
        ENV["OPENAI_API_KEY"] = "from-env"

        assert_equal "from-env", Inferrer.new(config: Config.new).send(:api_key)
        assert_equal "from-config", Inferrer.new(config: Config.new(api_key: "from-config")).send(:api_key)
      ensure
        saved.nil? ? ENV.delete("OPENAI_API_KEY") : ENV["OPENAI_API_KEY"] = saved
      end

      def test_api_base_is_not_applied_to_non_openai_providers
        inferrer = Inferrer.new(config: Config.new(provider: :anthropic, api_key: "k"))

        context_config = inferrer.send(:llm_context).config

        refute_equal Config.new.api_base, context_config.anthropic_api_base.to_s
        assert_equal "k", context_config.anthropic_api_key
      end

      def test_infer_returns_empty_intent_without_calling_the_llm_when_no_events
        chat = FakeChat.new(nil)
        def chat.ask(_prompt) = raise("should not be called")

        intent = Inferrer.new(chat: chat).infer([], repo: "/repo")

        assert_equal "No recent activity detected.", intent.goal
        assert_equal "low", intent.confidence
      end

      def test_infer_parses_well_formed_yaml_response
        chat = FakeChat.new(<<~YAML)
          goal: Building the activity monitor gem.
          confidence: high
          evidence:
            - abc1234 add feature
          open_questions:
            - inference cadence?
        YAML

        intent = Inferrer.new(chat: chat).infer([SAMPLE_EVENT], repo: "/repo")

        assert_equal "Building the activity monitor gem.", intent.goal
        assert_equal "high", intent.confidence
        assert_equal ["abc1234 add feature"], intent.evidence
        assert_equal ["inference cadence?"], intent.open_questions
        refute_nil intent.generated_at
      end

      def test_infer_falls_back_to_raw_text_on_malformed_yaml
        chat = FakeChat.new("not yaml: [unterminated")

        intent = Inferrer.new(chat: chat).infer([SAMPLE_EVENT], repo: "/repo")

        assert_equal "not yaml: [unterminated", intent.goal
        assert_equal "unknown", intent.confidence
        assert_empty intent.evidence
      end

      def test_infer_strips_yaml_fenced_code_block
        chat = FakeChat.new(<<~RESPONSE)
          ```yaml
          goal: Fenced goal.
          confidence: medium
          ```
        RESPONSE

        intent = Inferrer.new(chat: chat).infer([SAMPLE_EVENT], repo: "/repo")

        assert_equal "Fenced goal.", intent.goal
        assert_equal "medium", intent.confidence
      end
    end
  end
end
