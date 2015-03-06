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

require 'rspec'
require 'rspec/its'
require 'mixlib/shellout'

# An RSpec helper module for testing command-line tools.
#
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
  # Path to the temporary directory created for the current example.
  # @return [String]
  let(:temp_path) do |example|
    example.metadata[:rspec_command_temp_path]
  end

  # @!attribute [r] fixture_root
  # Base path for the fixtures directory. Default value is 'fixtures'.
  # @return [String]
  # @example
  #   let(:fixture_root) { 'data' }
  let(:fixture_root) { 'fixtures' }

  # @!attribute [r] _environment
  # @!visibility private
  # Accumulator for environment variables.
  # @see RSpecCommand.environment
  let(:_environment) { Hash.new }

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
      path = [
        find_file(example_path) {|path| Dir.entries(path).find {|ent| ent.end_with?('.gemspec') } },
        find_file(example_path, 'Gemfile'),
      ].find {|v| v }
      File.dirname(path)
    end
  end

  # Find a fixture file.
  def find_fixture(example_path, path)
    find_file(example_path, File.join(fixture_root, path), find_gem_base(example_path))
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
