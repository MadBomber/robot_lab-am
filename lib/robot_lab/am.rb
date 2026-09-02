# frozen_string_literal: true

require_relative "am/version"
require_relative "am/config"
require_relative "am/event"
require_relative "am/event_log"
require_relative "am/redactor"
require_relative "am/intent"
require_relative "am/inferrer"
require_relative "am/intent_writer"
require_relative "am/watchers/git_watcher"
require_relative "am/watchers/claude_watcher"
require_relative "am/watchers/terminal_watcher"
require_relative "am/collector"
require_relative "am/pid_file"
require_relative "am/heartbeat"
require_relative "am/daemon"
require_relative "am/daemon_controller"
require_relative "am/launchd"
require_relative "am/cli"

module RobotLab
  module Am
    class Error < StandardError; end

    class << self
      # Process-wide Config (defaults.yml -> user config file ->
      # RLAM_* env vars). Components use it for any setting not
      # passed to them explicitly.
      def config
        @config ||= Config.new
      end

      # Test hook: drop the memoized config so changed env vars are re-read.
      def reset_config!
        @config = nil
      end
    end
  end
end
