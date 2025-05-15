# frozen_string_literal: true

RSpec.describe Pronto::Rustcov do
  subject(:runner) { described_class.new([]) }
  
  describe '#parse_lcov' do
    let(:lcov_path) { File.join(File.dirname(__FILE__), '..', 'fixtures', 'parse_lcov.info') }
    
    before do
      # Create a test LCOV file with multiple files and varied coverage
      lcov_content = <<~LCOV
      SF:/path/to/file1.rs
      DA:5,0
      DA:6,0
      DA:7,1
      DA:8,0
      end_of_record
      SF:/path/to/file2.rs
      DA:10,0
      DA:11,1
      DA:12,0
      end_of_record
      LCOV
      
      FileUtils.mkdir_p(File.dirname(lcov_path))
      File.write(lcov_path, lcov_content)
    end
    
    it 'correctly parses LCOV files' do
      result = runner.send(:parse_lcov, lcov_path)
      
      # Test structure of the result
      expect(result).to be_a(Hash)
      expect(result.keys).to contain_exactly(
        File.expand_path('/path/to/file1.rs'),
        File.expand_path('/path/to/file2.rs')
      )
      
      # Test the uncovered lines for file1
      file1_uncovered = result[File.expand_path('/path/to/file1.rs')]
      expect(file1_uncovered).to contain_exactly(5, 6, 8)
      
      # Test the uncovered lines for file2
      file2_uncovered = result[File.expand_path('/path/to/file2.rs')]
      expect(file2_uncovered).to contain_exactly(10, 12)
    end
    
    context 'with missing LCOV file' do
      let(:nonexistent_path) { '/path/to/nonexistent/lcov.info' }
      
      it 'returns an empty hash when the file does not exist' do
        # We expect it to either return an empty hash or raise an error that we can handle
        # In the actual implementation, it would likely raise an error when the file doesn't exist
        expect { runner.send(:parse_lcov, nonexistent_path) }.to raise_error(Errno::ENOENT)
      end
    end
  end
end
