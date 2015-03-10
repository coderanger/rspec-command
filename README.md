# RSpec-Command

[![Build Status](https://img.shields.io/travis/coderanger/rspec-command.svg)](https://travis-ci.org/coderanger/rspec-command)
[![Gem Version](https://img.shields.io/gem/v/rspec-command.svg)](https://rubygems.org/gems/rspec-command)
[![Coverage](https://img.shields.io/codecov/c/github/coderanger/rspec-command.svg)](https://codecov.io/github/coderanger/rspec-command)
[![Gemnasium](https://img.shields.io/gemnasium/coderanger/rspec-command.svg)](https://gemnasium.com/coderanger/rspec-command)
[![License](https://img.shields.io/badge/license-Apache_2-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)

`rspec-command` is a helper module for using RSpec to test command-line
applications.

## Quick Start

Add `gem 'rspec-command'` to your `Gemfile` and then configure it in your
`spec_helper.rb`:

```ruby
require 'rspec_command'

RSpec.configure do |config|
  config.include RSpecCommand
end
```

You can then use the helpers in your specs:

```ruby
require 'spec_helper'

describe 'myapp' do
  command 'myapp --version'
  its(:stdout) { is_expected.to include('1.0.0') }
end
```

## command

The core helper is `command`. It takes a command to run and sets it as the
subject for the example group. The command can be given as a string, array, or
block. If the command is given as an array, no shell processing is done before
running it. If the gem you are running inside has a Gemfile, all commands will
be run inside a `bundle exec`. Each command is run in a new temporary directory
so the results of one test won't affect others.

`command` also optionally takes a hash of options to pass through to
`Mixlib::ShellOut.new`. Some common options include `:input` to provide data on
stdin and `:timeout` to change the execution timeout.

The subject will be set to a `Mixlib::ShellOut` object so you can use
`rspec-its` to check individual attributes:

```ruby
describe 'myapp' do
  command 'myapp --version'
  its(:stdout) { is_expected.to include '1.0.0' }
  its(:stderr) { is_expected.to eq '' }
  its(:exitstatus) { is_expected.to eq 0 }
end
```

## file

The `file` method writes a file in to the temporary directory. You can provide
the file content as either a string or a block:

```ruby
describe 'myapp' do
  command 'myapp read data1.txt data2.txt'
  file 'data1.txt', <<-EOH
a thing
EOH
  file 'data2.txt' do
    "another thing #{Time.now}"
  end
  its(:stdout) { is_expected.to include '2 files imported' }
end
```

## fixture_file

The `fixture_file` method copies a file or folder from a fixture to the
temporary directory:

```ruby
describe 'myapp' do
  command 'myapp read entries/'
  fixture_file 'entries'
  its(:stdout) { is_expected.to include '4 files imported' }
end
```

These fixtures are generally kept in `spec/fixtures` but it can be customized
by redefining `let(:fixture_root)`.

## environment

The `environment` method sets environment variables for subprocesses run by
`command`:

```ruby
describe 'myapp' do
  command 'myapp show'
  environment MYAPP_DEBUG: true
  its(:stderr) { is_expected.to include '[debug]' }
end
```

## match_fixture

The `match_fixture` matcher lets you check the files created by a command
against a fixture:

```ruby
describe 'myapp' do
  command 'myapp write'
  it { is_expected.to match_fixture 'write_data' }
end
```

## License

Copyright 2015, Noah Kantrowitz

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
