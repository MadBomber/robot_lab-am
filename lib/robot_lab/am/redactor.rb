# frozen_string_literal: true

module RobotLab
  module Am
    # Masks obvious secrets in event summaries before they reach the event
    # store or an LLM, per ARCHITECTURE.md's Privacy & redaction section.
    # Terminal commands and git WIP output are the risky sources (API keys in
    # `export` statements, credentials in fixtures). Deliberately pattern-based
    # and conservative — it catches the common shapes, not every possible leak.
    module Redactor
      MASK = "[REDACTED]"

      # `NAME=value` / `name: value` where the name smells like a credential.
      KEY_VALUE = /(\b[\w-]*(?:key|token|secret|password|passwd|credential)s?\b["']?\s*(?:=>|[=:])\s*["']?)([^\s"']+)/i

      # `Authorization: Bearer <token>` and friends.
      BEARER = /\b(bearer\s+)([^\s"']+)/i

      # Well-known token formats that are secrets wherever they appear.
      KNOWN_TOKEN = /
        \b(?:
          sk-[A-Za-z0-9_-]{16,}          # OpenAI-style
          | AKIA[0-9A-Z]{16}             # AWS access key id
          | gh[pousr]_[A-Za-z0-9]{20,}   # GitHub tokens
          | github_pat_[A-Za-z0-9_]{20,} # GitHub fine-grained PAT
          | xox[abprs]-[A-Za-z0-9-]{10,} # Slack tokens
        )\b
      /x

      module_function

      def redact_event(event)
        event.with(summary: redact(event.summary))
      end

      def redact(text)
        text.gsub(KEY_VALUE, "\\1#{MASK}")
            .gsub(BEARER, "\\1#{MASK}")
            .gsub(KNOWN_TOKEN, MASK)
      end
    end
  end
end
