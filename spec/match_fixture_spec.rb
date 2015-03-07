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

describe RSpecCommand::MatchFixture do
  describe 'in an example' do
    subject { nil }

    context 'with a single file' do
      before { IO.write(File.join(temp_path, 'data.txt'), "Fixture data.\n") }
      it { is_expected.to match_fixture('data.txt') }
    end # /context with a single file

    context 'with a non-existent file' do
      it { is_expected.to_not match_fixture('data.txt') }
    end # /context with a non-existent file

    context 'with a single file that does not match' do
      before { IO.write(File.join(temp_path, 'data.txt'), "Other data.\n") }
      it { is_expected.to_not match_fixture('data.txt') }
    end # /context with a single file that does not match

    context 'with a folder' do
      before do
        Dir.mkdir(File.join(temp_path, 'sub'))
        IO.write(File.join(temp_path, 'sub', 'sub1.txt'), "Subfixture 1.\n")
        IO.write(File.join(temp_path, 'sub', 'sub2.txt'), "Subfixture 2.\n")
      end
      it { is_expected.to match_fixture('sub') }
    end # /context with a folder

    context 'with a folder with an extra file' do
      before do
        Dir.mkdir(File.join(temp_path, 'sub'))
        IO.write(File.join(temp_path, 'sub', 'sub1.txt'), "Subfixture 1.\n")
        IO.write(File.join(temp_path, 'sub', 'sub2.txt'), "Subfixture 2.\n")
        IO.write(File.join(temp_path, 'sub', 'sub3.txt'), "Subfixture 3.\n")
      end
      it { is_expected.to_not match_fixture('sub') }
    end # /context with a folder with an extra file

    context 'with a folder with a missing file' do
      before do
        Dir.mkdir(File.join(temp_path, 'sub'))
        IO.write(File.join(temp_path, 'sub', 'sub1.txt'), "Subfixture 1.\n")
      end
      it { is_expected.to_not match_fixture('sub') }
    end # /context with a folder with a missing file

    context 'with a folder that does not match' do
      before do
        Dir.mkdir(File.join(temp_path, 'sub'))
        IO.write(File.join(temp_path, 'sub', 'sub1.txt'), "Subfixture 1.\n")
        IO.write(File.join(temp_path, 'sub', 'sub2.txt'), "Subfixture 3.\n")
      end
      it { is_expected.to_not match_fixture('sub') }
    end # /context with a folder with a missing file
  end # /describe in an example

  describe '#failure_message' do
    let(:path) { nil }
    subject { described_class.new(File.expand_path('../fixtures', __FILE__), temp_path, path, path).failure_message }

    context 'with a non-existent file' do
      let(:path) { 'data.txt' }
      it { is_expected.to include('data.txt is not found in files') }
    end # /context with a non-existent file

    context 'with a single file that does not match' do
      let(:path) { 'data.txt' }
      before { IO.write(File.join(temp_path, 'data.txt'), "Other data.\n") }
      it { is_expected.to include('data.txt does not match fixture:') }
      it { is_expected.to include('-Fixture data.') }
      it { is_expected.to include('+Other data.') }
    end # /context with a single file that does not match

    context 'with a folder with an extra file' do
      let(:path) { 'sub' }
      before do
        Dir.mkdir(File.join(temp_path, 'sub'))
        IO.write(File.join(temp_path, 'sub', 'sub1.txt'), "Subfixture 1.\n")
        IO.write(File.join(temp_path, 'sub', 'sub2.txt'), "Subfixture 2.\n")
        IO.write(File.join(temp_path, 'sub', 'sub3.txt'), "Subfixture 3.\n")
      end
      it { is_expected.to include('sub/sub3.txt is not found in fixture') }
    end # /context with a folder with an extra file

    context 'with a folder with a missing file' do
      let(:path) { 'sub' }
      before do
        Dir.mkdir(File.join(temp_path, 'sub'))
        IO.write(File.join(temp_path, 'sub', 'sub1.txt'), "Subfixture 1.\n")
      end
      it { is_expected.to include('sub/sub2.txt is not found in files') }
    end # /context with a folder with a missing file

    context 'with a folder that does not match' do
      let(:path) { 'sub' }
      before do
        Dir.mkdir(File.join(temp_path, 'sub'))
        IO.write(File.join(temp_path, 'sub', 'sub1.txt'), "Subfixture 1.\n")
        IO.write(File.join(temp_path, 'sub', 'sub2.txt'), "Subfixture 3.\n")
      end
      it { is_expected.to include('sub/sub2.txt does not match fixture:') }
      it { is_expected.to include('-Subfixture 2.') }
      it { is_expected.to include('+Subfixture 3.') }
    end # /context with a folder with a missing file
  end # /describe #failure_message

  describe '#differ' do
    subject { described_class.new(nil, nil, nil, nil).send(:differ) }
    # Basically just check that it isn't throwing errors
    it { is_expected.to_not be_nil}
    it { is_expected.to respond_to(:diff) }
  end # /describe #differ
end
