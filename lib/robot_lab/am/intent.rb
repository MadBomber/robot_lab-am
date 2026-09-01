# frozen_string_literal: true

module RobotLab
  module Am
    # The inferred goal/direction, structured per ARCHITECTURE.md's
    # "Inference engine" section.
    Intent = Data.define(:goal, :confidence, :evidence, :open_questions, :generated_at)
  end
end
