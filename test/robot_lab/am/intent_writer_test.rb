# frozen_string_literal: true

require "test_helper"

module RobotLab
  module Am
    class IntentWriterTest < Minitest::Test
      def test_write_creates_front_matter_and_prose
        with_tmp_dir do |dir|
          intent = Intent.new(goal: "Building the activity monitor.", confidence: "high",
                              evidence: ["commit abc1234"], open_questions: ["cadence?"],
                              generated_at: "2026-09-01T00:00:00Z")

          path = IntentWriter.new(repo: dir).write(intent)

          assert_equal File.join(dir, ".robot_lab_am", "current_intent.md"), path
          _, front_matter_text, prose = File.read(path).split(/^---$/, 3)
          data = YAML.safe_load(front_matter_text)

          assert_equal "high", data["confidence"]
          assert_equal ["commit abc1234"], data["evidence"]
          assert_includes prose, "Building the activity monitor."
        end
      end
    end
  end
end
