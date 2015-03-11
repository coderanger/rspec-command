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

require 'rake'
require 'rspec'

require 'rspec_command'


module RSpecCommand
  # An RSpec helper module for testing Rake tasks without running them in a
  # full subprocess. This improves test speed while still giving you most of
  # the benefits of integration testing.
  #
  # @api public
  # @since 1.0.0
  # @example
  #   RSpec.configure do |config|
  #     config.include RSpecCommand::Rake
  #   end
  # @example Enable for a single example group
  #   describe 'mytask' do
  #     rakefile <<-EOH
  #       ...
  #     EOH
  #     rake_task 'mytask'
  #     its(:stdout) { it_expected.to include('1.0.0') }
  #   end
  module Rake
    # @!classmethods
    module ClassMethods
      # Run a Rake task as the subject of this example group. The subject will
      # be a string returned by {#capture_output}.
      #
      # @param name [String] Name of the task to execute.
      # @param args [Array<Object>] Arguments to pass to the task.
      # @return [void]
      # @example
      #   describe 'mytask' do
      #     rakefile 'require "myapp/rake_tasks"'
      #     rake_task 'mytask'
      #     its(:stdout) { is_expected.to include 'Complete!' }
      #   end
      def rake_task(name, *args)
        metadata[:rake] = true
        subject do
          exitstatus = []
          capture_output do
            Process.waitpid fork {
              # :nocov:
              # Because #init reads from ARGV and will try to parse rspec's flags.
              ARGV.replace([])
              Dir.chdir(temp_path)
              ENV.update(_environment)
              rake = ::Rake::Application.new.tap do |rake|
                ::Rake.application = rake
                rake.init
                rake.load_rakefile
              end
              rake[name].invoke(*args)
            }
            exitstatus << $?.exitstatus
            # :nocov:
          end.tap do |output|
            output.define_singleton_method(:exitstatus) { exitstatus.first }
          end
        end
      end

      # Write out a Rakefile to the temporary directory for this example group.
      # Content can be passed as either a string or a block.
      #
      # @param content [String] Rakefile content.
      # @param block [Proc] Optional block to return the Rakefile content.
      # @return [void]
      # @example
      #   describe 'mytask' do
      #     rakefile <<-EOH
      #   task 'mytask' do
      #     ...
      #   end
      #   EOH
      #     rake_task 'mytask'
      #     its(:stdout) { is_expected.to include 'Complete!' }
      #   end
      def rakefile(content=nil, &block)
        file('Rakefile', content, &block)
      end

      def included(klass)
        super
        # Pull this in as a dependency.
        klass.send(:include, RSpecCommand)
        klass.extend ClassMethods
      end
    end

    extend ClassMethods
  end
end
