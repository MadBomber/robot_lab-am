# frozen_string_literal: true

require "test_helper"

class RobotLab::TestAm < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::RobotLab::Am::VERSION
  end
end
