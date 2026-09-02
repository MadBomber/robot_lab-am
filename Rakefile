# frozen_string_literal: true

# Quality gates (quality, rubocop_check, flog_check, flay_check, ...) and
# documentation tasks (doc_builder, doc_server) live in asgard — see .loki
# and the shared dev/*.loki files it imports. This Rakefile keeps only the
# tasks asgard itself delegates to: the test suite and the bundler gem
# lifecycle.

require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb', 'test/**/test_*.rb'].exclude('**/*_helper.rb')
  t.verbose = true
  t.ruby_opts << '-rtest_helper'
end

task default: :test

desc 'Run tests with verbose output'
task :test_verbose do
  ENV['TESTOPTS'] = '--verbose'
  Rake::Task[:test].invoke
end

desc 'Run a single test file'
task :test_file, [:file] do |_t, args|
  ruby "test/#{args[:file]}"
end
