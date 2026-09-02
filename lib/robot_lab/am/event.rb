# frozen_string_literal: true

module RobotLab
  module Am
    # One normalized activity signal, per the shape decided in
    # ARCHITECTURE.md's "Ingestion & normalization" section.
    Event = Data.define(:timestamp, :repo, :source, :kind, :summary) do
      def to_h_json
        { timestamp: timestamp, repo: repo, source: source, kind: kind, summary: summary }
      end

      # Identity for read-side dedupe (Collector). "wip" events are stamped
      # with collection time, so two reads of the same dirty tree never share
      # a timestamp — their identity is the summary alone.
      def fingerprint
        parts = [repo, source, kind, summary]
        parts << timestamp unless kind == "wip"
        parts.join("\x1F")
      end
    end
  end
end
