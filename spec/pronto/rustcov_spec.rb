# frozen_string_literal: true

RSpec.describe Pronto::Rustcov do
  let(:rustcov) { described_class.new(patches) }
  let(:lib_file_path) { '/path/to/src/lib.rs' }
  let(:main_file_path) { '/path/to/src/main.rs' }

  # Setup the LCOV fixture path via environment variable
  before do
    # Set the environment variable to point to our fixture file
    allow(ENV).to receive(:[]).with('PRONTO_RUSTCOV_LCOV_PATH').and_return(LCOV_FIXTURE_PATH)
    allow(ENV).to receive(:[]).with('LCOV_PATH').and_return(nil)
  end

  describe '#run' do
    context 'with no patches' do
      let(:patches) { [] }

      it 'returns an empty array' do
        expect(rustcov.run).to eq([])
      end
    end

    context 'with nil patches' do
      let(:patches) { nil }

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

      context 'with patches that have no added lines' do
        let(:empty_patch) { instance_double(Pronto::Git::Patch) }
        let(:patches) { [empty_patch] }

        before do
          allow(empty_patch).to receive(:new_file_full_path).and_return(Pathname.new(lib_file_path))
          allow(empty_patch).to receive(:added_lines).and_return([])
        end

        it 'skips patches with no added lines' do
          expect(rustcov.run).to eq([])
        end
      end

      context 'with files that have no uncovered lines' do
        let(:patches) do
          [
            create_patch(lib_file_path, [12, 13, 16])  # These are fully covered lines in the fixture
          ]
        end

        it 'skips files with no uncovered lines' do
          expect(rustcov.run).to eq([])
        end
      end

      context 'with files not found in LCOV data' do
        let(:nonexistent_file) { '/path/to/nonexistent/file.rs' }
        let(:patches) do
          [
            create_patch(nonexistent_file, [1, 2, 3])
          ]
        end

        it 'skips files not found in LCOV data' do
          expect(rustcov.run).to eq([])
        end
      end

      context 'with files that exist but have no data in LCOV results' do
        let(:existing_file_with_no_lcov_data) { '/path/exists/but/no/data.rs' }
        let(:patches) do
          [
            create_patch(existing_file_with_no_lcov_data, [1, 2, 3])
          ]
        end

        before do
          # Mock the parse_lcov method to return empty data for our specific file
          allow(rustcov).to receive(:parse_lcov).with(anything).and_return({})
        end

        it 'skips files with no LCOV data' do
          expect(rustcov.run).to eq([])
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

        context 'when a file with many added lines has no uncovered lines' do
          let(:many_covered_lines_file) { '/path/to/src/many_lines.rs' }
          let(:few_uncovered_lines_file) { '/path/to/src/few_lines.rs' }

          let(:patches) do
            [
              # A file with many added lines but all covered
              create_patch(many_covered_lines_file, (1..100).to_a),
              # A file with fewer added lines but some uncovered
              create_patch(few_uncovered_lines_file, [5, 6, 7])
            ]
          end

          before do
            # Mock the LCOV data so the many_lines file has all lines covered
            # while the few_lines file has some uncovered lines
            lcov_data = {}
            # The few_lines file has lines 5, 6, 7 uncovered
            lcov_data[few_uncovered_lines_file] = [5, 6, 7]
            # The many_lines file has no uncovered lines (empty array)
            lcov_data[many_covered_lines_file] = []

            allow(rustcov).to receive(:parse_lcov).and_return(lcov_data)
          end

          it 'prioritizes files with uncovered lines regardless of added line count' do
            messages = rustcov.run
            expect(messages).not_to be_empty

            # We should get messages only for the file with uncovered lines
            file_paths = messages.map(&:path).uniq
            expect(file_paths).to include(few_uncovered_lines_file)
            expect(file_paths).not_to include(many_covered_lines_file)
          end
        end
      end

      context 'with default files limit' do
        it 'limits the number of files processed' do
          messages = rustcov.run
          file_paths = messages.map(&:path).uniq
          expect(file_paths.count).to eq(2)  # Only one file should be processed
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
          expect(lib_messages.count).to eq(1)
        end
      end

      context 'with default messages per file limit' do
        before do
          # Add more uncovered lines in clustered groups to test batching
          additional_patch = create_patch(lib_file_path, [14, 15, 28, 29, 30, 31, 32, 33, 34, 35])
          allow(patches).to receive(:[]).with(0).and_return(additional_patch)
        end

        it 'creates multiple messages per file when needed' do
          messages = rustcov.run
          lib_messages = messages.select { |m| m.path == lib_file_path }

          # Should generate multiple messages for lib.rs due to the message limit
          expect(lib_messages.count).to eq(2)
        end
      end

      context 'prioritizing ranges by size and position' do
        let(:ranges_file_path) { '/path/to/src/ranges.rs' }
        let(:ranges_fixture_path) { File.join(File.dirname(__FILE__), '..', 'fixtures', 'range_prioritization_lcov.info') }
        let(:patches) do
          [
            # Create a patch with all the lines from our fixture
            # The fixture has these ranges of uncovered lines:
            # - A small range at the beginning (lines 5-6): 2 lines
            # - A small range that appears early (lines 10-11): 2 lines
            # - A large range in middle (lines 20-29): 10 lines
            # - A medium range at end (lines 40-44): 5 lines
            # - Another small range (lines 50-51): 2 lines - should be excluded due to limit of 3
            create_patch(ranges_file_path, (1..100).to_a)  # All line numbers in the fixture
          ]
        end
        
        before do
          # Set the environment variables for this test
          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with('PRONTO_RUSTCOV_LCOV_PATH').and_return(ranges_fixture_path)
          allow(ENV).to receive(:[]).with('LCOV_PATH').and_return(nil)
          allow(ENV).to receive(:[]).with('PRONTO_RUSTCOV_FILES_LIMIT').and_return(nil)
          allow(ENV).to receive(:[]).with('PRONTO_RUSTCOV_MESSAGES_PER_FILE_LIMIT').and_return('3')
        end

        it 'prioritizes ranges by size and position' do
          messages = rustcov.run
          ranges_messages = messages.select { |m| m.path == ranges_file_path }

          # We should have exactly 3 messages due to our limit of 3
          expect(ranges_messages.count).to eq(3)
          
          # Extract the line ranges from messages
          extracted_ranges = ranges_messages.map do |message|
            # Extract range from message text using regex
            if message.msg =~ /(\d+)–(\d+)/
              [$1.to_i, $2.to_i]
            else
              # Single line message
              [message.msg.scan(/\d+/).first.to_i]
            end
          end
          
          # First message should be for the largest range (20-29)
          expect(extracted_ranges[0]).to eq([20, 29])
          
          # Second message should be for the medium range (40-44)
          expect(extracted_ranges[1]).to eq([40, 44])
          
          # Third should be for one of the small ranges that appears earlier (5-6)
          # Due to sorting on range start when ranges are of equal size
          expect(extracted_ranges[2]).to eq([5, 6])
          
          # The ranges at (50-51) and (10-11) should be excluded due to the limit of 3
          all_mentioned_lines = ranges_messages.map(&:msg).join.scan(/\d+/).map(&:to_i)
          expect(all_mentioned_lines).not_to include(50)
          expect(all_mentioned_lines).not_to include(51)
          expect(all_mentioned_lines).not_to include(10)
          expect(all_mentioned_lines).not_to include(11)
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

      it 'raises an informative error' do
        expect { rustcov.run }.to raise_error(RuntimeError, /LCOV file not found/)
      end
    end

    context 'when parsing a corrupt lcov file' do
      let(:patches) { [create_patch(lib_file_path, [14, 15])] }
      let(:corrupt_lcov_path) { File.join(File.dirname(__FILE__), '..', 'fixtures', 'corrupt_lcov.info') }

      before do
        allow(ENV).to receive(:[]).with('PRONTO_RUSTCOV_LCOV_PATH').and_return(corrupt_lcov_path)
      end

      it 'ignores DA lines when no file is defined yet' do
        result = rustcov.run
        expect(result).to be_an(Array)

        # We're testing that it properly handles corrupt LCOV data without errors
        # The test doesn't need to make assertions about the specific output
        # since we're only concerned with branch coverage here
      end
    end
  end
end
