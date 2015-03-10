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
    extend RSpec::SharedContext
    # @!attribute [r] rake
    # Return a loaded
    let(:rake) do
      ::Rake::Application.new.tap do |rake|
        ::Rake.application = rake
        # Because #init reads from ARGV and will try to parse rspec's flags.
        Rake._patch([], ARGV.clone, lambda {|v| ARGV.replace(v) }) do
          rake.init
        end
        # Can't use block form of chdir because that throws a warning when Rake
        # chdir's internally.
        Rake._rake_env(temp_path, _environment) do
          rake.load_rakefile
        end
      end
    end

    # Patch some kind of global value in a mildly safe way.
    #
    # @api private
    # @param val [Object] Value to set for the duration of the block.
    # @param get [Proc, Object] Callable to get the current value or the current value itself.
    # @param set [Proc] Callable to set the value. Should take one argument.
    # @param block [Proc] Block to run with the patch.
    def self._patch(val, get, set, &block)
      old = get.is_a?(Proc) ? get.call : get
      set.call(val)
      block.call
    ensure
      set.call(old)
    end

    # Patch various things to setup the fake rake environment.
    #
    # @api private
    # @param block [Proc] Block to run in the patched environment.
    def self._rake_env(temp_path, environment, &block)
      Rake._patch(temp_path, Dir.pwd, lambda {|v| Dir.chdir(v) }) do
        Rake._patch(ENV.to_hash.merge(environment), ENV.to_hash, lambda {|v| ENV.replace(v) }, &block)
      end
    end

    # @!classmethods
    module ClassMethods
      def rake_task(name, *args)
        subject do
          Rake._rake_env(temp_path, _environment) do
            capture_output do
              rake[name].invoke(*args)
            end
          end
        end
      end

      def rakefile(content=nil, &block)
        file('Rakefile', content, &block)
      end

      def included(klass)
        super
        klass.include RSpecCommand
        klass.extend ClassMethods
      end
    end

    extend ClassMethods
  end
end
