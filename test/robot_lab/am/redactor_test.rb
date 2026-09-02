# frozen_string_literal: true

require "test_helper"

module RobotLab
  module Am
    class RedactorTest < Minitest::Test
      def test_redacts_key_value_assignments
        assert_equal "export ANTHROPIC_API_KEY=[REDACTED]",
                     Redactor.redact("export ANTHROPIC_API_KEY=sk-ant-abc123def456ghi789")
        assert_equal "password: [REDACTED]", Redactor.redact("password: hunter2")
        assert_equal "token = [REDACTED] --verbose", Redactor.redact("token = abc123 --verbose")
      end

      def test_redacts_quoted_values_but_keeps_quotes
        assert_equal %(secret="[REDACTED]"), Redactor.redact(%(secret="s3cr3t"))
      end

      def test_redacts_bearer_tokens
        assert_equal "curl -H 'Authorization: Bearer [REDACTED]'",
                     Redactor.redact("curl -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.payload.sig'")
      end

      def test_redacts_well_known_token_formats
        assert_equal "found [REDACTED] in env", Redactor.redact("found AKIAIOSFODNN7EXAMPLE in env")
        assert_equal "[REDACTED]", Redactor.redact("ghp_abcdefghijklmnopqrstuvwxyz012345")
        assert_equal "[REDACTED]", Redactor.redact("xoxb-1234567890-abcdefghij")
      end

      def test_leaves_ordinary_text_alone
        ["bundle exec rake test", "abc1234 add token support docs", "git status --short"].each do |text|
          assert_equal text, Redactor.redact(text)
        end
      end

      def test_redact_event_returns_new_event_with_redacted_summary
        event = Event.new(timestamp: "2026-09-01T00:00:00Z", repo: "/repo", source: "terminal",
                          kind: "command", summary: "export MY_TOKEN=abc123")

        redacted = Redactor.redact_event(event)

        assert_equal "export MY_TOKEN=[REDACTED]", redacted.summary
        assert_equal "export MY_TOKEN=abc123", event.summary
        assert_equal event.timestamp, redacted.timestamp
      end
    end
  end
end
