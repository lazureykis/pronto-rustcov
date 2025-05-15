# frozen_string_literal: true

RSpec.describe Pronto::Rustcov do
  let(:rustcov) { described_class.new(patches) }
  let(:lib_file_path) { '/path/to/src/lib.rs' }
  let(:main_file_path) { '/path/to/src/main.rs' }
  
  # Setup the LCOV fixture path via environment variable
  before do
    # Set the environment variable to point to our fixture file
    allow(ENV).to receive(:[]).with('PRONTO_RUSTCOV_LCOV_PATH').and_return(LCOV_FIXTURE_PATH)
  end
  
  describe '#run' do
    context 'with no patches' do
      let(:patches) { [] }
      
      it 'returns an empty array' do
        expect(rustcov.run).to eq([])
      end
    end
    
    context 'with patches for files with uncovered lines' do
      let(:patches) do
        [
          # Patch for lib.rs with uncovered lines 14, 15, 28-30
          create_patch(lib_file_path, [14, 15, 28, 29, 30]),
          # Patch for main.rs with uncovered lines 7, 8, 12
          create_patch(main_file_path, [7, 8, 12])
        ]
      end
      
      it 'returns messages for files with uncovered lines' do
        messages = rustcov.run
        expect(messages).to be_an(Array)
        expect(messages).not_to be_empty
        
        # Verify there are messages for both files
        file_paths = messages.map(&:path).uniq
        expect(file_paths).to include(lib_file_path, main_file_path)
        
        # Verify the message content
        messages.each do |message|
          expect(message).to be_a(Pronto::Message)
          expect(message.msg).to include('Test coverage is missing')
          expect([lib_file_path, main_file_path]).to include(message.path)
          expect(message.level).to eq(:warning)
        end
      end
      
      context 'with custom files limit' do
        before do
          allow(ENV).to receive(:[]).with('PRONTO_RUSTCOV_FILES_LIMIT').and_return('1')
        end
        
        it 'limits the number of files processed' do
          messages = rustcov.run
          file_paths = messages.map(&:path).uniq
          expect(file_paths.count).to eq(1)  # Only one file should be processed
        end
      end
      
      context 'with custom messages per file limit' do
        before do
          allow(ENV).to receive(:[]).with('PRONTO_RUSTCOV_MESSAGES_PER_FILE_LIMIT').and_return('1')
          
          # Add more uncovered lines in clustered groups to test batching
          additional_patch = create_patch(lib_file_path, [14, 15, 28, 29, 30, 31, 32, 33, 34, 35])
          allow(patches).to receive(:[]).with(0).and_return(additional_patch)
        end
        
        it 'creates multiple messages per file when needed' do
          messages = rustcov.run
          lib_messages = messages.select { |m| m.path == lib_file_path }
          
          # Should generate multiple messages for lib.rs due to the message limit
          expect(lib_messages.count).to be > 1
          
          # Each message should have no more than 1 range
          lib_messages.each do |message|
            ranges = message.msg.scan(/\d+\u2013\d+|\d+/).count
            expect(ranges).to eq(1) # Only one range per message
          end
        end
      end
    end
    
    context 'when the lcov file is not found' do
      let(:patches) { [create_patch(lib_file_path, [14, 15])] }
      
      before do
        # Point to a non-existent file for this test case
        nonexistent_path = '/path/to/nonexistent/lcov.info'
        allow(ENV).to receive(:[]).with('PRONTO_RUSTCOV_LCOV_PATH').and_return(nonexistent_path)
        allow(File).to receive(:foreach).with(nonexistent_path).and_raise(Errno::ENOENT)
      end
      
      it 'returns an empty array' do
        expect(rustcov.run).to eq([])
      end
    end
  end
end
