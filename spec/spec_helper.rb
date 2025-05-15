require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  enable_coverage :branch
  primary_coverage :line
  # Generate HTML and JSON reports for CI
  formatter SimpleCov::Formatter::HTMLFormatter
end

require 'bundler/setup'
require 'pronto/rustcov'
require 'fileutils'

# Setup fixtures path constants
FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures')
LCOV_FIXTURE_PATH = File.join(FIXTURES_PATH, 'lcov.info')

# Helper method to create realistic Pronto::Git::Patch objects for testing
def create_patch(file_path, added_lines_numbers)
  patch = instance_double(Pronto::Git::Patch)
  allow(patch).to receive(:new_file_full_path).and_return(Pathname.new(file_path))
  allow(patch).to receive(:new_file_path).and_return(file_path)
  
  lines = added_lines_numbers.map do |num|
    line = instance_double(Pronto::Git::Line)
    allow(line).to receive(:new_lineno).and_return(num)
    allow(line).to receive(:commit_sha).and_return('abc1234') # Add commit_sha method
    line
  end
  
  allow(patch).to receive(:added_lines).and_return(lines)
  patch
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  
  # Clear environment variables before each test
  config.before(:each) do
    # Default stub for all ENV lookups is nil
    allow(ENV).to receive(:[]).and_return(nil)
    
    # Default values for our specific environment variables
    allow(ENV).to receive(:[]).with('PRONTO_RUSTCOV_FILES_LIMIT').and_return(nil)
    allow(ENV).to receive(:[]).with('PRONTO_RUSTCOV_MESSAGES_PER_FILE_LIMIT').and_return(nil)
    allow(ENV).to receive(:[]).with('PRONTO_RUSTCOV_LCOV_PATH').and_return(LCOV_FIXTURE_PATH)
    allow(ENV).to receive(:[]).with('LCOV_PATH').and_return(nil)
  end
end
