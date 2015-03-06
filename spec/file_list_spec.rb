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

require 'spec_helper'

describe RSpecCommand::MatchFixture::FileList do
  let(:path) { nil }
  subject { described_class.new(temp_path, path) }
  def write(path)
    path = File.join(temp_path, path)
    FileUtils.mkdir_p(File.dirname(path))
    IO.write(path, '')
  end

  context 'with a single file' do
    let(:path) { 'data.txt' }
    before { write('data.txt') }
    its(:full_path) { is_expected.to eq File.join(temp_path, 'data.txt') }
    its(:files) { is_expected.to eq ['data.txt'] }
    its(:full_files) { is_expected.to eq [File.join(temp_path, 'data.txt')] }
  end # /context with a single file

  context 'with a non-existent file' do
    let(:path) { 'data.txt' }
    its(:full_path) { is_expected.to eq File.join(temp_path, 'data.txt') }
    its(:files) { is_expected.to eq [] }
    its(:full_files) { is_expected.to eq [] }
  end # /context with a non-existent file

  context 'with a folder' do
    let(:path) { 'sub' }
    before { write('sub/one.txt'); write('sub/two.txt') }
    its(:full_path) { is_expected.to eq File.join(temp_path, 'sub') }
    its(:files) { is_expected.to eq ['sub/one.txt', 'sub/two.txt'] }
    its(:full_files) do
      is_expected.to eq [
        File.join(temp_path, 'sub/one.txt'),
        File.join(temp_path, 'sub/two.txt'),
      ]
    end
  end # /context with a folder

  describe '#relative' do
    subject { described_class.new('/test', nil).relative('/test/data.txt') }
    it { is_expected.to eq 'data.txt' }
  end # /describe #relative
end
