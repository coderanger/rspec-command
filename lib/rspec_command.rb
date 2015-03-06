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

  let(:temp_path) do |example|
    example.metadata[:rspec_command_temp_path]
  end

  let(:fixture_root) { 'fixtures' }

  let(:_environment) { Hash.new }

  private

  def find_file(example_path, fixture=nil, backstop=nil, &block)
    path = File.dirname(File.expand_path(example_path))
    last_path = nil
    while path != last_path && path != backstop
      if block
        fixture_path = block.call(path)
        return fixture_path = fixture_path
      else
        fixture_path = File.join(path, fixture)
        return fixture_path if File.exists?(fixture_path)
      end
      last_path = path
      path = File.dirname(path)
    end
    nil
  end

  def find_gem_base(example_path)
    @gem_base ||= begin
      path = [
        find_file(example_path) {|path| Dir.entries(path).find {|ent| ent.end_with?('.gemspec') } },
        find_file(example_path, 'Gemfile'),
      ].find {|v| v }
      File.dirname(path)
    end
  end

  def find_fixture(example_path, path)
    find_file(example_path, File.join(fixture_root, path), find_gem_base(example_path))
  end

  # @!classmethods
  module ClassMethods
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

    def file(path, content=nil, &block)
      raise "file path should be relative the the temporary directory." if path == File.expand_path(path)
      before do
        content = block.call if block
        dest_path = File.join(temp_path, path)
        FileUtils.mkdir_p(File.dirname(dest_path))
        IO.write(dest_path, content)
      end
    end

    def fixture_file(path)
    def fixture_file(path, dest=nil)
      raise "file path should be relative the the temporary directory." if path == File.expand_path(path)
      before do |example|
        fixture_path = find_fixture(example.file_path, path)
        dest_path = File.join(temp_path, dest || path)
        FileUtils.cp_r(fixture_path, dest_path)
      end
    end

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
