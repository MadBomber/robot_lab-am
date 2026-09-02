# frozen_string_literal: true

require "digest"
require "fileutils"
require "rbconfig"

module RobotLab
  module Am
    # Generates and installs the per-repo launchd agent plist from
    # ARCHITECTURE.md's Deployment model — process supervision, start on
    # login, restart on crash. One agent per watched repo; the agent just
    # runs `am start --foreground` and lets launchd own the process.
    #
    # Install/uninstall only touch the plist file; loading it into launchd is
    # left to the user (the CLI prints the launchctl commands) so this class
    # has no side effects beyond the file it writes.
    class Launchd
      LABEL_PREFIX = "com.madbomber.robot-lab-am"
      DEFAULT_AGENTS_DIR = File.expand_path("~/Library/LaunchAgents")

      def initialize(repo:, interval: nil, debounce: nil,
                     agents_dir: DEFAULT_AGENTS_DIR, program: nil, config: nil)
        @repo = repo
        @interval = interval
        @debounce = debounce
        @agents_dir = agents_dir
        @program = program
        @config = config
      end

      # Repo basename plus a short path hash: readable, and unique even for
      # two checkouts with the same basename.
      def label
        "#{LABEL_PREFIX}.#{File.basename(@repo)}-#{Digest::SHA256.hexdigest(@repo)[0, 8]}"
      end

      def plist_path
        File.join(@agents_dir, "#{label}.plist")
      end

      def install
        FileUtils.mkdir_p(@agents_dir)
        File.write(plist_path, plist_xml)
        plist_path
      end

      def uninstall
        raise Error, "no launchd agent installed for #{@repo} (expected #{plist_path})" unless File.exist?(plist_path)

        FileUtils.rm_f(plist_path)
        plist_path
      end

      def plist_xml
        log = File.join(@repo, ".robot_lab_am", "daemon.log")
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
            <key>Label</key>
            <string>#{xml_escape(label)}</string>
            <key>ProgramArguments</key>
            <array>
          #{program_arguments.map { |arg| "    <string>#{xml_escape(arg)}</string>" }.join("\n")}
            </array>
            <key>WorkingDirectory</key>
            <string>#{xml_escape(@repo)}</string>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>#{xml_escape(log)}</string>
            <key>StandardErrorPath</key>
            <string>#{xml_escape(log)}</string>
          </dict>
          </plist>
        XML
      end

      private

      # launchd starts agents with a minimal PATH, so invoke the script with
      # the same ruby this process is running under rather than trusting the
      # shebang's `env ruby` to resolve.
      def config   = @config ||= Am.config
      def interval = @interval || config.interval
      def debounce = @debounce || config.debounce

      def program
        @program ||= File.expand_path($PROGRAM_NAME)
      end

      # interval/debounce are baked into the plist so the launchd-run daemon
      # behaves the same as the `am install` invocation that created it,
      # regardless of later config-file edits.
      def program_arguments
        [RbConfig.ruby, program, "start", "--foreground", "--repo", @repo,
         "--interval", interval.to_s, "--debounce", debounce.to_s]
      end

      def xml_escape(text)
        text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
      end
    end
  end
end
