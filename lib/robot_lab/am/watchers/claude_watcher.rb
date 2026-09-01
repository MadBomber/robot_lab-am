# frozen_string_literal: true

require "json"

module RobotLab
  module Am
    module Watchers
      # The human's own plain-language messages from their most recent
      # Claude Code session transcript for this repo. Richest, lowest-effort
      # source per ARCHITECTURE.md — already on disk, no new instrumentation.
      class ClaudeWatcher
        PROJECTS_DIR = File.expand_path("~/.claude/projects")

        def initialize(repo:, limit: 20, projects_dir: PROJECTS_DIR)
          @repo = File.expand_path(repo)
          @limit = limit
          @projects_dir = projects_dir
        end

        def events
          file = latest_transcript
          return [] unless file

          human_messages(file)
        end

        private

        def latest_transcript
          dir = project_dir
          return nil unless dir

          Dir.glob(File.join(dir, "*.jsonl")).max_by { |f| File.mtime(f) }
        end

        # Claude Code slugifies the cwd into a project directory name by
        # replacing every non-alphanumeric character with "-". Older
        # sessions kept underscores; fall back to a normalized match so
        # both schemes resolve to the same repo.
        def project_dir
          slug  = @repo.gsub(/[^a-zA-Z0-9]/, "-")
          exact = File.join(@projects_dir, slug)
          return exact if Dir.exist?(exact)

          normalized = slug.tr("_", "-")
          Dir.glob(File.join(@projects_dir, "*")).find do |dir|
            File.directory?(dir) && File.basename(dir).tr("_", "-") == normalized
          end
        end

        def human_messages(file)
          File.readlines(file).last(500).filter_map { |line| human_message_event(line) }.last(@limit)
        end

        def human_message_event(line)
          record = JSON.parse(line)
          return nil unless record["type"] == "user"

          text = extract_text(record.dig("message", "content"))
          return nil if text.nil? || text.strip.empty?

          Event.new(timestamp: record["timestamp"], repo: @repo, source: "claude_code",
                    kind: "user_message", summary: text.strip[0, 500])
        rescue JSON::ParserError
          nil
        end

        # Only plain text blocks count as "the human said something" — this
        # skips synthetic user turns that are actually tool_result payloads.
        def extract_text(content)
          return content if content.is_a?(String)
          return nil unless content.is_a?(Array)

          blocks = content.select { |block| block["type"] == "text" }
          return nil if blocks.empty?

          blocks.map { |block| block["text"] }.join("\n")
        end
      end
    end
  end
end
