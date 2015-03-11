#
# Copyright 2015, Noah Kantrowitz
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'

describe RSpecCommand::Rake do
  include RSpecCommand::Rake

  describe '#rakefile' do
    rakefile "task 'mytask'\n"
    it { expect(File.exists?(File.join(temp_path, 'Rakefile'))).to eq true }
  end # /describe #rakefile

  describe '#rake_task' do
    context 'with a simple task' do
      rakefile <<-EOH
task 'mytask' do
  puts 'complete'
end
EOH
      rake_task 'mytask'
      its(:stdout) { is_expected.to eq "complete\n" }
      its(:stderr) { is_expected.to eq '' }
      its(:exitstatus) { is_expected.to eq 0 }
    end # /context with a simple task

    context 'with an environment variable' do
      rakefile <<-EOH
task 'mytask' do
  puts ENV['MYVAR']
end
EOH
      environment MYVAR: 'envvar'
      rake_task 'mytask'
      its(:stdout) { is_expected.to eq "envvar\n" }
      its(:stderr) { is_expected.to eq '' }
      its(:exitstatus) { is_expected.to eq 0 }
      it { expect(ENV['MYVAR']).to be_nil }
    end # /context with an environment variable

    context 'with no rakefile' do
      rake_task 'mytask'
      its(:stderr) { is_expected.to include 'No Rakefile found' }
      its(:exitstatus) { is_expected.to eq 1 }
    end # /context with no rakefile

    context 'with a non-existent task' do
      rakefile ''
      rake_task 'mytask'
      its(:stderr) { is_expected.to include "Don't know how to build task 'mytask'" }
      its(:exitstatus) { is_expected.to eq 1 }
    end # /context with a non-existent task

    context 'with a task with arguments' do
      rakefile <<-'EOH'
task 'mytask', %w{arg1 arg2} do |t, args|
  args.with_defaults(arg2: 'default')
  puts "#{args[:arg1]} #{args[:arg2]}"
end
EOH
      rake_task 'mytask', 'one'
      its(:stdout) { is_expected.to eq "one default\n" }
      its(:stderr) { is_expected.to eq '' }
      its(:exitstatus) { is_expected.to eq 0 }
    end # /context with a task with arguments

    context 'with a task that fails' do
      rakefile <<-EOH
task 'failure' do
  puts 'before'
  raise "OMG"
  puts 'after'
end
EOH
      rake_task 'failure'
      its(:stdout) { is_expected.to eq "before\n" }
      its(:stderr) { is_expected.to include "Rakefile:3:in `block in <top (required)>': OMG (RuntimeError)" }
      its(:exitstatus) { is_expected.to eq 1 }
    end # /context with a task that fails

    context 'with a task that fails with a specific exitstatus' do
      rakefile <<-EOH
task 'specific_failure' do
  puts 'specific before'
  Kernel.exit(42)
  puts 'specific after'
end
EOH
      rake_task 'specific_failure'
      its(:stdout) { is_expected.to eq "specific before\n" }
      its(:stderr) { is_expected.to eq '' }
      its(:exitstatus) { is_expected.to eq 42 }
    end # /context with a task that fails with a specific exitstatus

    context 'regression test for require-based Rakefiles and multiple tests' do
      file 'mytask.rb', 'task :mytask do puts "complete" end'
      rakefile '$:.unshift(File.dirname(__FILE__)); require "mytask"'
      rake_task 'mytask'
      # Run twice to force the bug.
      its(:stdout) { is_expected.to include "complete\n" }
      its(:stdout) { is_expected.to include "complete\n" }
    end
  end # /describe #rake_task
end
