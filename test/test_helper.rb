# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/test/"
  add_filter "/vendor/"
  add_group "Am", "lib/robot_lab/am"
  enable_coverage :branch
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "robot_lab"
require "robot_lab/am"

require "minitest/autorun"
require "minitest/reporters"
require "tmpdir"

# rubocop:disable Style/FileOpen, Style/GlobalStdStream
$stdout = File.open("test_output.txt", "w").tap { |f| f.sync = true }

class TerminalSummaryReporter < Minitest::Reporters::BaseReporter
  def report
    super
    ok    = failures.zero? && errors.zero?
    badge = ok ? "\e[32mPASS\e[0m" : "\e[31mFAIL\e[0m"
    STDOUT.puts "[#{badge}] #{count} tests, #{failures} failures, #{errors} errors, " \
                "#{skips} skips (#{format("%.2f", total_time)}s) — see test_output.txt"
    STDOUT.flush
  end
end
# rubocop:enable Style/FileOpen, Style/GlobalStdStream

Minitest::Reporters.use! [
  Minitest::Reporters::DefaultReporter.new(color: false, slow_count: 5),
  TerminalSummaryReporter.new
]

module RobotLab
  module Am
    module TestHelpers
      def with_tmp_dir
        Dir.mktmpdir { |dir| yield File.realpath(dir) }
      end

      # A minimal fake robot_lab Robot: responds to #run(prompt) the way
      # RobotLab::Robot does, without any network call.
      FakeRobot = Struct.new(:response) do
        Result = Struct.new(:last_text_content)

        def run(_prompt)
          Result.new(response)
        end
      end
    end
  end
end

Minitest::Test.include RobotLab::Am::TestHelpers
