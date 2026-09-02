# frozen_string_literal: true

require "fileutils"

module RobotLab
  module Am
    # The daemon's pid on disk (.robot_lab_am/daemon.pid). A pid file alone
    # can lie after a crash, which is why the daemon also writes a Heartbeat —
    # but liveness here is still checked against the real process table
    # (signal 0), not just the file's existence.
    class PidFile
      def initialize(path)
        @path = path
      end

      def write(pid = Process.pid)
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, pid.to_s)
      end

      def read
        return nil unless File.exist?(@path)

        pid = File.read(@path).to_i
        pid.positive? ? pid : nil
      end

      def delete
        FileUtils.rm_f(@path)
      end

      def exist?
        File.exist?(@path)
      end

      def alive?
        pid = read
        return false unless pid

        Process.kill(0, pid)
        true
      rescue Errno::ESRCH
        false
      rescue Errno::EPERM
        true
      end
    end
  end
end
