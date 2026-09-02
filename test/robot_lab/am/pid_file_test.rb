# frozen_string_literal: true

require "test_helper"

module RobotLab
  module Am
    class PidFileTest < Minitest::Test
      def test_write_and_read_round_trip
        with_tmp_dir do |dir|
          pid_file = PidFile.new(File.join(dir, "nested", "daemon.pid"))
          pid_file.write(12_345)

          assert_equal 12_345, pid_file.read
          assert pid_file.exist?
        end
      end

      def test_write_defaults_to_current_process_pid
        with_tmp_dir do |dir|
          pid_file = PidFile.new(File.join(dir, "daemon.pid"))
          pid_file.write

          assert_equal Process.pid, pid_file.read
        end
      end

      def test_read_returns_nil_for_missing_or_garbage_file
        with_tmp_dir do |dir|
          path = File.join(dir, "daemon.pid")
          pid_file = PidFile.new(path)

          assert_nil pid_file.read

          File.write(path, "not a pid")
          assert_nil pid_file.read
        end
      end

      def test_alive_reflects_the_process_table
        with_tmp_dir do |dir|
          pid_file = PidFile.new(File.join(dir, "daemon.pid"))

          refute pid_file.alive?, "no pid file should read as not alive"

          pid_file.write(Process.pid)
          assert pid_file.alive?

          dead = Process.spawn("true")
          Process.wait(dead)
          pid_file.write(dead)
          refute pid_file.alive?
        end
      end

      def test_delete_removes_the_file
        with_tmp_dir do |dir|
          pid_file = PidFile.new(File.join(dir, "daemon.pid"))
          pid_file.write(1)
          pid_file.delete

          refute pid_file.exist?
          pid_file.delete # idempotent
        end
      end
    end
  end
end
