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


module RSpecCommand
  # @api private
  # @since 1.0.0
  class MatchFixture
    # Create a new matcher for a fixture.
    #
    # @param fixture_root [String] Absolute path to the fixture folder.
    # @param local_root [String] Absolute path to test folder to compare against.
    # @param fixture_path [String] Relative path to the fixture to compare against.
    # @param local_path [String] Optional relative path to the test data to compare against.
    def initialize(fixture_root, local_root, fixture_path, local_path=nil)
      @fixture = FileList.new(fixture_root, fixture_path)
      @local = FileList.new(local_root, local_path)
    end

    # Primary callback for RSpec matcher API.
    #
    # @param cmd Ignored.
    # @return [Boolean]
    def matches?(cmd)
      files_match? && file_content_match?
    end

    # Callback for RSpec. Returns a human-readable description for the matcher.
    #
    # @return [String]
    def description
      "match fixture #{@fixture.path}"
    end

    # Callback fro RSpec. Returns a human-readable failure message.
    #
    # @return [String]
    def failure_message
      matching_files = @fixture.files & @local.files
      fixture_only_files = @fixture.files - @local.files
      local_only_files = @local.files - @fixture.files
      buf = "expected fixture #{@fixture.path} to match files:\n"
      (@fixture.files | @local.files).sort.each do |file|
        if matching_files.include?(file)
          local_file = @local.absolute(file)
          fixture_file = @fixture.absolute(file)
          if File.directory?(local_file) && File.directory?(fixture_file)
            # Do nothing
          elsif File.directory?(fixture_file)
            buf << "  #{file} should be a directory\n"
          elsif File.directory?(local_file)
            buf << "  #{file} should not be a directory"
          else
            actual = IO.read(local_file)
            expected = IO.read(fixture_file)
            if actual != expected
              # Show a diff
              buf << "  #{file} does not match fixture:"
              buf << differ.diff(actual, expected).split(/\n/).map {|line| '    '+line }.join("\n")
            end
          end
        elsif fixture_only_files.include?(file)
          buf << "  #{file} is not found\n"
        elsif local_only_files.include?(file)
          buf << "  #{file} should not exist\n"
        end
      end
      buf
    end

    private

    # Do the file entries match? Doesn't check content.
    #
    # @return [Boolean]
    def files_match?
      @fixture.files == @local.files
    end

    # Do the file contents match?
    #
    # @return [Boolean]
    def file_content_match?
      @fixture.full_files.zip(@local.full_files).all? do |fixture_file, local_file|
        if File.directory?(fixture_file)
          File.directory?(local_file)
        else
          !File.directory?(local_file) && IO.read(fixture_file) == IO.read(local_file)
        end
      end
    end

    # Return a Differ object to make diffs.
    #
    # @note This is using a nominally private API. It could break in the future.
    # @return [RSpec::Support::Differ]
    # @example
    #   differ.diff(actual, expected)
    def differ
      RSpec::Expectations.differ
    end

    class FileList
      attr_reader :root, :path

      # @param root [String] Absolute path to the root of the files.
      # @param path [String] Relative path to the specific files.
      def initialize(root, path=nil)
        @root = root
        @path = path
      end

      # Absolute path to the target.
      def full_path
        @full_path ||= path ? File.join(root, path) : root
      end

      # Absolute paths to target files that exist.
      def full_files
        @full_files ||= if File.directory?(full_path)
          Dir.glob(File.join(full_path, '**', '*'), File::FNM_DOTMATCH).sort.reject {|p| relative(p) == '.' }
        else
          [full_path].select {|path| File.exist?(path) }
        end
      end

      # Relative paths to the target files that exist.
      def files
        @files ||= full_files.map {|file| relative(file) }
      end

      # Convert an absolute path to a relative one
      def relative(file)
        if File.directory?(full_path)
          file[full_path.length+1..-1]
        else
          File.basename(file)
        end
      end

      # Convert a relative path to an absolute one.
      def absolute(file)
        if File.directory?(full_path)
          File.join(full_path, file)
        else
          full_path
        end
      end
    end

  end
end
