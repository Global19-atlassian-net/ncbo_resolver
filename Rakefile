require "bundler/gem_tasks"
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs = []
  t.test_files = FileList['test/**/test*.rb'].select { |x| !x["resource_index"]}
end

