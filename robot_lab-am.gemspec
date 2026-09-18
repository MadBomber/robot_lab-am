# frozen_string_literal: true

require_relative "lib/robot_lab/am/version"

Gem::Specification.new do |spec|
  spec.name = "robot_lab-am"
  spec.version = RobotLab::Am::VERSION
  spec.authors = ["Dewayne VanHoozer"]
  spec.email = ["dvanhoozer@gmail.com"]

  spec.summary = "Watches terminal, git, and Claude Code activity to infer what you're working on."
  spec.description = "Standalone background daemon that watches a repo's git activity, Claude Code " \
                     "session transcripts, and terminal commands, then infers the current goal/direction " \
                     "via a one-shot RubyLLM call to a local model. Writes an intent artifact any tool " \
                     "can read — robot_lab-to uses it to seed takeover runs, but nothing here requires RobotLab."
  spec.homepage = "https://github.com/MadBomber/robot_lab-am"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[Gemfile .gitignore test/ bin/console bin/setup])
    end
  end
  spec.bindir = "bin"
  spec.executables = ["am"]
  spec.require_paths = ["lib"]

  spec.add_dependency "myway_config", "~> 0.1"
  spec.add_dependency "ruby_llm", "~> 2.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://guides.rubygems.org/make-your-own-gem/
end
