# frozen_string_literal: true

module RobotLab
  module Am
    # One normalized activity signal, per the shape decided in
    # ARCHITECTURE.md's "Ingestion & normalization" section.
    Event = Data.define(:timestamp, :repo, :source, :kind, :summary) do
      def to_h_json
        { timestamp: timestamp, repo: repo, source: source, kind: kind, summary: summary }
      end
    end
  end
end
