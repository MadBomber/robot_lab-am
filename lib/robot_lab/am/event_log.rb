# frozen_string_literal: true

require "json"
require "fileutils"

module RobotLab
  module Am
    # Append-only JSONL event store — one Event per line. Chosen over SQLite
    # per ARCHITECTURE.md's Storage section: the only consumer is an LLM
    # summarization pass over a bounded recent window, not ad hoc queries.
    class EventLog
      def initialize(path)
        @path = path
      end

      def append(event)
        FileUtils.mkdir_p(File.dirname(@path))
        File.open(@path, "a") { |f| f.puts(event.to_h_json.to_json) }
      end

      def append_all(events)
        events.each { |event| append(event) }
      end

      def all
        return [] unless File.exist?(@path)

        File.readlines(@path).filter_map { |line| parse_line(line) }
      end

      private

      def parse_line(line)
        Event.new(**JSON.parse(line, symbolize_names: true))
      rescue JSON::ParserError
        nil
      end
    end
  end
end
