# frozen_string_literal: true

require "test_helper"

module RobotLab
  module Am
    class ConfigTest < Minitest::Test
      ENV_KEYS = %w[RLAM_PROVIDER RLAM_MODEL RLAM_API_BASE RLAM_API_KEY
                    RLAM_INTERVAL RLAM_DEBOUNCE
                    RLAM_INFERENCE_WINDOW RLAM_TERMINAL_LOG].freeze

      def with_env(vars)
        saved = ENV_KEYS.to_h { |k| [k, ENV.fetch(k, nil)] }
        vars.each { |k, v| ENV[k] = v }
        Am.reset_config!
        yield
      ensure
        saved.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
        Am.reset_config!
      end

      def test_bundled_defaults
        config = Config.new

        assert_equal :openai, config.provider
        assert_equal "qwen/qwen3.8-27b", config.model
        assert_equal "http://localhost:1234/v1", config.api_base
        assert_equal 15, config.interval
        assert_equal 300, config.debounce
        assert_equal 100, config.inference_window
        assert_equal File.expand_path("~/.activity_monitor/terminal_activity.log"), config.terminal_log
      end

      def test_env_vars_override_defaults_with_type_coercion
        with_env("RLAM_INTERVAL" => "45", "RLAM_PROVIDER" => "anthropic",
                 "RLAM_MODEL" => "llama-3.3-70b") do
          config = Config.new

          assert_equal 45, config.interval
          assert_equal :anthropic, config.provider
          assert_equal "llama-3.3-70b", config.model
        end
      end

      def test_constructor_overrides_beat_env_vars
        with_env("RLAM_DEBOUNCE" => "600") do
          config = Config.new(debounce: 60)

          assert_equal 60, config.debounce
        end
      end

      def test_nil_constructor_overrides_are_ignored
        config = Config.new(interval: nil, model: nil, debounce: 42)

        assert_equal 15, config.interval
        assert_equal "qwen/qwen3.8-27b", config.model
        assert_equal 42, config.debounce
      end

      def test_terminal_log_override_is_path_expanded
        config = Config.new(terminal_log: "~/custom/commands.log")

        assert_equal File.expand_path("~/custom/commands.log"), config.terminal_log
      end

      def test_am_config_is_memoized_and_resettable
        first = Am.config

        assert_same first, Am.config
        Am.reset_config!
        refute_same first, Am.config
      ensure
        Am.reset_config!
      end
    end
  end
end
