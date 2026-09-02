# frozen_string_literal: true

require "test_helper"

module RobotLab
  module Am
    class LaunchdTest < Minitest::Test
      def build_launchd(dir, repo: "/Users/me/src/my_repo")
        Launchd.new(repo: repo, agents_dir: File.join(dir, "LaunchAgents"), program: "/opt/gems/bin/am")
      end

      def test_label_is_readable_and_unique_per_repo_path
        with_tmp_dir do |dir|
          one = build_launchd(dir, repo: "/a/my_repo")
          two = build_launchd(dir, repo: "/b/my_repo")

          assert_match(/\Acom\.madbomber\.robot-lab-am\.my_repo-\h{8}\z/, one.label)
          refute_equal one.label, two.label
        end
      end

      def test_install_writes_the_plist
        with_tmp_dir do |dir|
          launchd = build_launchd(dir)

          path = launchd.install

          assert_path_exists path
          assert_equal File.join(dir, "LaunchAgents", "#{launchd.label}.plist"), path
        end
      end

      def test_plist_contains_supervised_foreground_invocation
        with_tmp_dir do |dir|
          xml = build_launchd(dir).plist_xml

          assert_match %r{<string>#{Regexp.escape(RbConfig.ruby)}</string>}, xml
          assert_match %r{<string>/opt/gems/bin/am</string>}, xml
          %w[start --foreground --repo /Users/me/src/my_repo --interval --debounce].each do |arg|
            assert_match %r{<string>#{Regexp.escape(arg)}</string>}, xml
          end
          assert_match %r{<key>KeepAlive</key>\s*<true/>}, xml
          assert_match %r{<key>RunAtLoad</key>\s*<true/>}, xml
          assert_match %r{\.robot_lab_am/daemon\.log</string>}, xml
        end
      end

      def test_plist_escapes_xml_metacharacters_in_paths
        with_tmp_dir do |dir|
          xml = build_launchd(dir, repo: "/tmp/a&b<c>").plist_xml

          assert_includes xml, "/tmp/a&amp;b&lt;c&gt;"
          refute_includes xml, "<string>/tmp/a&b<c></string>"
        end
      end

      def test_uninstall_removes_the_plist
        with_tmp_dir do |dir|
          launchd = build_launchd(dir)
          path = launchd.install

          assert_equal path, launchd.uninstall
          refute_path_exists path
        end
      end

      def test_uninstall_raises_when_no_agent_installed
        with_tmp_dir do |dir|
          error = assert_raises(Error) { build_launchd(dir).uninstall }
          assert_match(/no launchd agent installed/, error.message)
        end
      end
    end
  end
end
