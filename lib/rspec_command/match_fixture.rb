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
  # @!visibility private
  # @since 1.0.0
  class MatchFixture
    def initialize(fixture_root, local_root, fixture_path, local_path)
      @fixture = FileList.new(fixture_root, fixture_path)
      @local = FileList.new(local_root, local_path)
    end

    def matches?(cmd)
      files_match? && file_content_match?
    end

    def description
      "match fixture #{@fixture.path}"
    end

    def failure_message
      matching_files = @fixture.files & @local.files
      fixture_only_files = @fixture.files - @local.files
      local_only_files = @local.files - @fixture.files
      buf = "expected fixture #{@fixture.path} to match files:\n"
      (@fixture.files | @local.files).sort.each do |file|
        if matching_files.include?(file)
          actual = IO.read(File.join(@local.root, file))
          expected = IO.read(File.join(@fixture.root, file))
          if actual != expected
            # Show a diff
            buf << "  #{file} does not match fixture:"
            buf << differ.diff(actual, expected).split(/\n/).map {|line| '    '+line }.join("\n")
          end
        elsif fixture_only_files.include?(file)
          buf << "  #{file} is not found in files\n"
        elsif local_only_files.include?(file)
          buf << "  #{file} is not found in fixture\n"
        end
      end
      buf
    end

    private

    def files_match?
      @fixture.files == @local.files
    end

    def file_content_match?
      @fixture.full_files.zip(@local.full_files).all? do |fixture_file, local_file|
        IO.read(fixture_file) == IO.read(local_file)
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
      def initialize(root, path)
        @root = root
        @path = path
      end

      # Absolute path to the target.
      def full_path
        @full_path ||= File.join(root, path)
      end

      # Absolute paths to target files that exist.
      def full_files
        @full_files ||= if File.directory?(full_path)
          Dir[File.join(full_path, '**', '*')].sort
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
        file[root.length+1..-1]
      end
    end

  end
end
