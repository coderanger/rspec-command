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

describe RSpecCommand do
  def read_temp(path)
    IO.read(File.join(temp_path, path))
  end

  describe '#command' do
    context 'true' do
      command 'true'
      its(:exitstatus) { is_expected.to eq 0 }
    end # /context true

    context 'false' do
      command 'false'
      it { expect { subject }.to raise_error(Mixlib::ShellOut::ShellCommandFailed) }
    end # /context false

    context 'with a block' do
      command { 'true' }
      its(:exitstatus) { is_expected.to eq 0 }
    end # /context with a block

    context 'with allow_error' do
      command 'false', allow_error: true
      its(:exitstatus) { is_expected.to eq 1 }
    end # /context with allow_error

    context 'with input' do
      command 'cat', input: "I'm a little teapot"
      its(:stdout) { is_expected.to eq "I'm a little teapot" }
    end # /context with input

    context 'check gemfile' do
      command 'env'
      its(:stdout) { is_expected.to include("BUNDLE_GEMFILE=#{File.expand_path('../../Gemfile', __FILE__)}") }
    end # /context check gemfile

    context 'echo * with shell' do
      command 'echo *'
      before { IO.write(File.join(temp_path, 'file'), '') }
      its(:stdout) { is_expected.to eq "file\n" }
    end # /context echo * with shell

    context 'echo * without shell' do
      command %w{echo *}
      before { IO.write(File.join(temp_path, 'file'), '') }
      its(:stdout) { is_expected.to eq "*\n" }
    end # /context echo * without shell

    context 'without a Gemfile' do
      command 'env'
      before { allow(self).to receive(:find_file).and_return(nil) }
      around do |example|
        begin
          old_gemfile = ENV.delete('BUNDLE_GEMFILE')
          example.run
        ensure
          ENV['BUNDLE_GEMFILE'] = old_gemfile if old_gemfile
        end
      end
      its(:stdout) { is_expected.to_not include('BUNDLE_GEMFILE') }
    end # /context without a Gemfile
  end # /describe #command

  describe '#file' do
    context 'with a simple file' do
      file 'data', 'Short and stout'
      subject { read_temp('data') }
      it { is_expected.to eq 'Short and stout' }
    end # /context with a simple file

    context 'with a block' do
      file 'data' do
        'Here is my handle'
      end
      subject { read_temp('data') }
      it { is_expected.to eq 'Here is my handle' }
    end # /context with a block

    context 'with a subfolder' do
      file 'sub/data', 'Here is my spout'
      subject { read_temp('sub/data') }
      it { is_expected.to eq 'Here is my spout' }
    end # /context with a subfolder

    context 'with an absolute path' do
      it { expect { self.class.file('/data', '') }.to raise_error }
    end # /context with an absolute path
  end # /describe #file

  describe '#fixture_file' do
    context 'with a single file fixture' do
      fixture_file 'data.txt'
      subject { read_temp('data.txt') }
      it { is_expected.to eq "Fixture data.\n" }
    end # /context with a single file fixture

    context 'with a directory fixture' do
      fixture_file 'sub'
      it { expect(read_temp('sub1.txt')).to eq "Subfixture 1.\n" }
      it { expect(read_temp('sub2.txt')).to eq "Subfixture 2.\n" }
    end # /context with a directory fixture

    context 'with a different dest' do
      fixture_file 'sub', 'other'
      it { expect(read_temp('other/sub1.txt')).to eq "Subfixture 1.\n" }
      it { expect(read_temp('other/sub2.txt')).to eq "Subfixture 2.\n" }
    end # /context with a different dest

    context 'with an absolute path' do
      it { expect { self.class.fixture_file('/data', '') }.to raise_error }
    end # /context with an absolute path

    context 'with a nested directory fixture' do
      fixture_file 'sub_nested'
      it { expect(read_temp('sub_nested.txt')).to eq "Subfixture nested.\n" }
      it { expect(read_temp('sub_inner/sub_inner1.txt')).to eq "Subfixture inner 1.\n" }
      it { expect(read_temp('sub_inner/sub_inner2.txt')).to eq "Subfixture inner 2.\n" }
    end # /context with a nested directory fixture
  end # /describe #fixture_file

  describe '#environment' do
    context 'with a single variable' do
      environment MY_KEY: 'true'
      command 'env'
      its(:stdout) { is_expected.to include("MY_KEY=true") }
    end # /context with a single variable

    context 'with a two variables' do
      environment MY_KEY: 'true'
      environment OTHER_KEY: '1'
      command 'env'
      its(:stdout) { is_expected.to include("MY_KEY=true") }
      its(:stdout) { is_expected.to include("OTHER_KEY=1") }
    end # /context with a two variables
  end # /describe #environment

  describe '#temp_path' do
    subject { temp_path }
    it { is_expected.to be_a(String) }
  end # /describe #temp_path

  describe '#fixture_root' do
    let(:fixture_root) { 'fixtures/sub' }
    fixture_file 'sub1.txt'
    subject { read_temp('sub1.txt') }
    it { is_expected.to eq "Subfixture 1.\n" }
  end # /describe #fixture_root

  describe '#find_file' do
    context 'with Gemfile' do
      subject { find_file(__FILE__, 'Gemfile') }
      it { is_expected.to eq File.expand_path('../../Gemfile', __FILE__) }
    end # /context with Gemfile

    context 'with a block' do
      subject { find_file(__FILE__) {|p| p } }
      it { is_expected.to eq File.dirname(__FILE__) }
    end # /context with a block

    context 'with a non-existant file' do
      subject { find_file(__FILE__, 'NOPE.GIF') }
      it { is_expected.to be_nil }
    end # /context with a non-existant file

    # This is important to check because otherwise the backstop test might be a
    # false negative.
    context 'with the gem root' do
      subject { find_file(__FILE__, 'rspec-command') }
      it { is_expected.to eq File.expand_path('../..', __FILE__) }
    end # /context with the gem root

    context 'with a backstop' do
      subject { find_file(__FILE__, 'rspec-command', File.expand_path('..', __FILE__)) }
      it { is_expected.to be_nil }
    end # /context with a backstop
  end # /describe #find_file

  describe '#find_gem_base' do
    subject { find_gem_base(__FILE__) }
    it { is_expected.to eq File.expand_path('../..', __FILE__) }
  end # /describe #find_gem_base

  describe '#find_fixture' do
    context 'with a fixture file' do
      subject { find_fixture(__FILE__, 'data.txt') }
      it { is_expected.to eq File.expand_path('../fixtures/data.txt', __FILE__) }
    end # /context with a fixture file

    context 'with no fixture path' do
      subject { find_fixture(__FILE__) }
      it { is_expected.to eq File.expand_path('../fixtures', __FILE__) }
    end # /context with no fixture path
  end # /describe #find_fixture

  describe '#capture_output' do
    context 'with puts' do
      subject do
        capture_output { puts 'test' }
      end
      it { is_expected.to eq "test\n" }
      its(:stdout) { is_expected.to eq "test\n" }
      its(:stderr) { is_expected.to eq '' }
      its(:exitstatus) { is_expected.to eq 0 }
    end # /context with puts

    context 'with STDERR.puts' do
      subject do
        capture_output { STDERR.puts 'test' }
      end
      it { is_expected.to eq '' }
      its(:stdout) { is_expected.to eq '' }
      its(:stderr) { is_expected.to eq "test\n" }
      its(:exitstatus) { is_expected.to eq 0 }
    end # /context with STDERR.puts

    context 'with $stderr.puts' do
      subject do
        capture_output { $stderr.puts 'test' }
      end
      it { is_expected.to eq '' }
      its(:stdout) { is_expected.to eq '' }
      its(:stderr) { is_expected.to eq "test\n" }
      its(:exitstatus) { is_expected.to eq 0 }
    end # /context with $stderr.puts

    context 'with a subproc' do
      subject do
        capture_output do
          # Can't use `` because that already captures stdout
          if pid = Process.fork
            Process.waitpid(pid)
          else
            exec('echo test')
          end
        end
      end
      it { is_expected.to eq "test\n" }
      its(:stdout) { is_expected.to eq "test\n" }
      its(:stderr) { is_expected.to eq '' }
      its(:exitstatus) { is_expected.to eq 0 }
    end # /context with a subproc

    context 'with a subproc to stderr' do
      subject do
        capture_output { `echo test >&2` }
      end
      it { is_expected.to eq '' }
      its(:stdout) { is_expected.to eq '' }
      its(:stderr) { is_expected.to eq "test\n" }
      its(:exitstatus) { is_expected.to eq 0 }
    end # /context with a subproc

    context 'with a block that raises an exception' do
      subject do
        capture_output do
          puts 'before'
          raise 'OMG'
          puts 'after'
        end
      end
      it { expect { subject }.to raise_error }
      it do
        begin
          subject
        rescue Exception => e
          expect(e).to respond_to(:output_so_far)
          expect(e.output_so_far).to eq "before\n"
        else
          raise 'Subject did not raise exception'
        end
      end
    end # /context with a block that raises an exception
  end # /describe #capture_output

  describe RSpecCommand::OutputString do
    subject { described_class.new('testout', 'testerr') }
    it { is_expected.to be_a String }
    it { is_expected.to eq 'testout' }
    its(:stdout) { is_expected.to eq 'testout' }
    its(:stderr) { is_expected.to eq 'testerr' }
    its(:exitstatus) { is_expected.to eq 0 }
  end # /describe RSpecCommand::OutputString
end
