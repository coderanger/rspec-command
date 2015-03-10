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

require 'fileutils'
require 'tempfile'

require 'rspec'
require 'rspec/its'
require 'mixlib/shellout'

require 'rspec_command/match_fixture'
require 'rspec_command/rake'


# An RSpec helper module for testing command-line tools.
#
# @api public
# @since 1.0.0
# @example Enable globally
#   RSpec.configure do |config|
#     config.include RSpecCommand
#   end
# @example Enable for a single example group
#   describe 'myapp' do
#     command 'myapp --version'
#     its(:stdout) { it_expected.to include('1.0.0') }
#   end
module RSpecCommand
  extend RSpec::SharedContext

  around do |example|
    Dir.mktmpdir('rspec_command') do |path|
      example.metadata[:rspec_command_temp_path] = path
      example.run
    end
  end

  # @!attribute [r] temp_path
  #   Path to the temporary directory created for the current example.
  #   @return [String]
  let(:temp_path) do |example|
    example.metadata[:rspec_command_temp_path]
  end

  # @!attribute [r] fixture_root
  #   Base path for the fixtures directory. Default value is 'fixtures'.
  #   @return [String]
  #   @example
  #     let(:fixture_root) { 'data' }
  let(:fixture_root) { 'fixtures' }

  # @!attribute [r] _environment
  #   @!visibility private
  #   @api private
  #   Accumulator for environment variables.
  #   @see RSpecCommand.environment
  let(:_environment) { Hash.new }

  # Matcher to compare files or folders from the temporary directory to a
  # fixture.
  #
  # @example
  #   describe 'myapp' do
  #     command 'myapp write'
  #     it { is_expected.to match_fixture('write_data') }
  #   end
  def match_fixture(fixture_path, local_path=fixture_path)
    MatchFixture.new(find_fixture(self.class.file_path), temp_path, fixture_path, local_path)
  end

  # Run a local block with $stdout and $stderr redirected to a strings. Useful
  # for running CLI code in unit tests. The returned string has `#stdout`,
  # `#stderr` and `#exitstatus` attributes to emulate the output from {.command}.
  #
  # @param block [Proc] Code to run.
  # @return [String]
  # @example
  #   describe 'my rake task' do
  #     subject do
  #       capture_output do
  #         Rake::Task['mytask'].invoke
  #       end
  #     end
  #   end
  def capture_output(&block)
  #   old_stdout = $stdout
  #   old_stderr = $stderr
  #   $stdout = StringIO.new('','w')
  #   $stderr = StringIO.new('','w')
  #   block.call
  #   StdoutString.new($stdout.string, $stderr.string)
  # ensure
  #   $stdout = old_stdout
  #   $stderr = old_stderr
    old_stdout = $stdout.dup
    old_stderr = $stderr.dup
    Tempfile.open('capture_stdout') do |tmp_stdout|
      Tempfile.open('capture_stderr') do |tmp_stderr|
        $stdout.reopen(tmp_stdout)
        $stdout.sync = true
        $stderr.reopen(tmp_stderr)
        $stderr.sync = true
        block.call
        # Rewind.
        tmp_stdout.seek(0, 0)
        tmp_stderr.seek(0, 0)
        # Read in the output.
        StdoutString.new(tmp_stdout.read, tmp_stderr.read)
      end
    end
  ensure
    $stdout.reopen(old_stdout)
    $stderr.reopen(old_stderr)
  end

  # String subclass to make string output look kind of like Mixlib::Shellout.
  #
  # #@!visibility private
  # #@api private
  # @see capture_stdout
  class StdoutString < String
    def initialize(stdout, stderr)
      super(stdout)
      @stderr = stderr
    end

    def stdout
      self
    end

    def stderr
      @stderr
    end

    def exitstatus
      0
    end
  end

  private

  # Search backwards along the working directory looking for a file, a la .git.
  # Either file or block must be given.
  #
  # @param example_path [String] Path of the current example file. Find via
  #   example.file_path.
  # @param file [String] Relative path to search for.
  # @param backstop [String] Path to not search past.
  # @param block [Proc] Block to use as a filter.
  # @return [String, nil]
  def find_file(example_path, file=nil, backstop=nil, &block)
    path = File.dirname(File.expand_path(example_path))
    last_path = nil
    while path != last_path && path != backstop
      if block
        block_val = block.call(path)
        return block_val if block_val
      else
        file_path = File.join(path, file)
        return file_path if File.exists?(file_path)
      end
      last_path = path
      path = File.dirname(path)
    end
    nil
  end

  # Find the base folder of the current gem.
  def find_gem_base(example_path)
    @gem_base ||= begin
      paths = []
      paths << find_file(example_path) do |path|
        spec_path = Dir.entries(path).find do |ent|
          ent.end_with?('.gemspec')
        end
        spec_path = File.join(path, spec_path) if spec_path
        spec_path
      end
      paths << find_file(example_path, 'Gemfile')
      File.dirname(paths.find {|v| v })
    end
  end

  # Find a fixture file or the fixture base folder.
  def find_fixture(example_path, path=nil)
    @fixture_base ||= find_file(example_path, fixture_root, find_gem_base(example_path))
    path ? File.join(@fixture_base, path) : @fixture_base
  end

  # @!classmethods
  module ClassMethods
    # Run a command as the subject of this example. The command can be passed in
    # as a string, array, or block. The subject will be a Mixlib::ShellOut
    # object, all attributes from there will work with rspec-its.
    #
    # @param cmd [String, Array] Command to run. If passed as an array, no shell
    #   expansion will be done.
    # @param options [Hash<Symbol, Object>] Options to pass to
    #   Mixlib::ShellOut.new.
    # @param block [Proc] Optional block to return a command to run.
    # @option options [Boolean] allow_error If true, don't raise an error on
    #   failed commands.
    # @example
    #   describe 'myapp' do
    #     command 'myapp show'
    #     its(:stdout) { is_expected.to match(/a thing/) }
    #   end
    def command(cmd=nil, options={}, &block)
      subject do |example|
        # If a block is given, use it to get the command.
        cmd = block.call if block
        # Try to find a Gemfile
        gemfile_path = find_file(example.file_path, 'Gemfile')
        gemfile_environment = gemfile_path ? {'BUNDLE_GEMFILE' => gemfile_path} : {}
        # Create the command
        allow_error = options.delete(:allow_error)
        full_cmd = if gemfile_path
          if cmd.is_a?(Array)
            %w{bundle exec} + cmd
          else
            "bundle exec #{cmd}"
          end
        else
          cmd
        end
        Mixlib::ShellOut.new(
          full_cmd,
          {
            cwd: temp_path,
            environment: gemfile_environment.merge(_environment),
          }.merge(options),
        ).tap do |cmd|
          # Run the command
          cmd.run_command
          cmd.error! unless allow_error
        end
      end
    end

    # Create a file in the temporary directory for this example.
    #
    # @param path [String] Path within the temporary directory to write to.
    # @param content [String] File data to write.
    # @param block [Proc] Optional block to return file data to write.
    # @example
    #   describe 'myapp' do
    #     command 'myapp read data.txt'
    #     file 'data.txt', <<-EOH
    #   a thing
    #   EOH
    #     its(:exitstatus) { is_expected.to eq 0 }
    #   end
    def file(path, content=nil, &block)
      raise "file path should be relative the the temporary directory." if path == File.expand_path(path)
      before do
        content = block.call if block
        dest_path = File.join(temp_path, path)
        FileUtils.mkdir_p(File.dirname(dest_path))
        IO.write(dest_path, content)
      end
    end

    # Copy fixture data from the spec folder to the temporary directory for this
    # example.
    #
    # @param path [String] Path of the fixture to copy.
    # @param dest [String] Optional destination path. By default the destination
    #   is the same as path.
    # @example
    #   describe 'myapp' do
    #     command 'myapp run test/'
    #     fixture_file 'test'
    #     its(:exitstatus) { is_expected.to eq 0 }
    #   end
    def fixture_file(path, dest=nil)
      raise "file path should be relative the the temporary directory." if path == File.expand_path(path)
      before do |example|
        fixture_path = find_fixture(example.file_path, path)
        dest_path = File.join(temp_path, dest || path)
        FileUtils.cp_r(fixture_path, dest_path)
      end
    end

    # Set an environment variable for this example.
    #
    # @param variables [Hash] Key/value pairs to set.
    # @example
    #   describe 'myapp' do
    #     command 'myapp show'
    #     environment DEBUG: true
    #     its(:stderr) { is_expected.to include('[debug]') }
    #   end
    def environment(variables)
      before do
        variables.each do |key, value|
          _environment[key.to_s] = value.to_s
        end
      end
    end

    def included(klass)
      super
      klass.extend ClassMethods
    end
  end

  extend ClassMethods
end
