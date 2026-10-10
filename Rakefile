# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "lib" << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

desc "Construye la gema e instálala localmente (deja disponible el comando vdl-btz)"
task :install do
  sh "gem build vdl-btz.gemspec"
  sh "gem install ./vdl-btz-#{File.read('lib/vdl_btz/version.rb')[/VERSION = "(.+)"/, 1]}.gem"
end

task default: :test
