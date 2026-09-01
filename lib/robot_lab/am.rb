# frozen_string_literal: true

require_relative "am/version"
require_relative "am/event"
require_relative "am/event_log"
require_relative "am/intent"
require_relative "am/inferrer"
require_relative "am/intent_writer"
require_relative "am/watchers/git_watcher"
require_relative "am/watchers/claude_watcher"
require_relative "am/watchers/terminal_watcher"
require_relative "am/cli"

module RobotLab
  module Am
    class Error < StandardError; end
  end
end
