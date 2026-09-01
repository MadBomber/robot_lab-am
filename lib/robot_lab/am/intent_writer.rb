# frozen_string_literal: true

require "yaml"
require "fileutils"

module RobotLab
  module Am
    # Writes the inferred Intent to .robot_lab_am/current_intent.md in the
    # watched repo — front matter + prose, the same shape as robot_lab-to's
    # decision files, under the same .robot_lab_<name>/ naming convention as
    # robot_lab-to's own .robot_lab_to/runs/<run_id>/ run state.
    class IntentWriter
      def initialize(repo:)
        @path = File.join(repo, ".robot_lab_am", "current_intent.md")
      end

      def write(intent)
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, render(intent))
        @path
      end

      private

      def render(intent)
        front_matter = {
          "confidence" => intent.confidence,
          "generated_at" => intent.generated_at,
          "evidence" => intent.evidence,
          "open_questions" => intent.open_questions
        }
        "#{YAML.dump(front_matter)}---\n\n#{intent.goal}\n"
      end
    end
  end
end
