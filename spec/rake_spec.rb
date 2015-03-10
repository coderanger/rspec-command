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

  describe '#rake' do
    context 'with a task' do
      file 'Rakefile', "task 'mytask'\n"
      subject { rake }
      it { is_expected.to be_a Rake::Application }
      its(['mytask']) { is_expected.to be_a Rake::Task }
    end # /context with a task

    context 'with no rakefile' do
      subject do
        # This prints a warning to stderr that I don't care about, I just need
        # the exception.
        capture_output { rake }
      end
      it { expect { subject }.to raise_error(SystemExit) }
    end # /context with no rakefile
  end # /describe #rake

  describe '#rakefile' do
    rakefile "task 'mytask'\n"
    it { expect(File.exists?(File.join(temp_path, 'Rakefile'))).to eq true }
    it { expect(rake).to be_truthy }
  end # /describe #rakefile

  describe '#rake_task' do
    context 'with a simple task' do
      rakefile <<-EOH
task 'mytask' do
  puts 'complete'
end
EOH
      rake_task 'mytask'
      its(:stdout) { is_expected.to include "complete\n" }
    end # /context with a simple task

    context 'with an environment variable' do
      rakefile <<-EOH
task 'mytask' do
  puts ENV['MYVAR']
end
EOH
      environment MYVAR: 'envvar'
      rake_task 'mytask'
      its(:stdout) { is_expected.to include "envvar\n" }
      it { expect(ENV['MYVAR']).to be_nil }
    end # /context with an environment variable
  end
end
