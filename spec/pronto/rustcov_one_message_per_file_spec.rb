# frozen_string_literal: true

RSpec.describe Pronto::Rustcov do
  subject(:runner) { described_class.new(patches) }
  
  let(:repo) { double('Pronto::Git::Repository') }
  let(:patches) { [] }
  let(:lcov_path) { File.join(File.dirname(__FILE__), '..', 'fixtures', 'lcov.info') }

  before do
    # Create a temporary directory for fixtures
    FileUtils.mkdir_p(File.join(File.dirname(__FILE__), '..', 'fixtures'))
  end

  describe '#one_message_per_file' do
    context 'with no patches' do
      it 'returns an empty array' do
        expect(runner.one_message_per_file(lcov_path)).to eq([])
      end
    end

    context 'with patches that have uncovered lines' do
      let(:file_path) { '/path/to/test_file.rs' }
      let(:patches) { [patch] }
      let(:patch) { instance_double(Pronto::Git::Patch) }
      let(:line) { instance_double(Pronto::Git::Line) }
      
      before do
        # Create a simple LCOV file with some uncovered lines
        lcov_content = <<~LCOV
        SF:#{file_path}
        DA:5,0
        DA:6,0
        DA:7,0
        DA:10,0
        DA:12,0
        DA:15,0
        DA:16,0
        DA:17,0
        DA:20,0
        DA:21,0
        DA:30,0
        end_of_record
        LCOV
        
        File.write(lcov_path, lcov_content)
        
        # Set up the patch and line doubles
        allow(patch).to receive(:new_file_full_path).and_return(Pathname.new(file_path))
        allow(patch).to receive(:new_file_path).and_return(file_path)
        allow(patch).to receive(:added_lines).and_return([line])
        
        # Set up the line double to represent line 5
        allow(line).to receive(:new_lineno).and_return(5)
      end

      context 'with default message limit' do
        it 'creates a message with properly grouped uncovered lines' do
          # Set up more lines
          lines = (5..7).map do |num|
            line_double = instance_double(Pronto::Git::Line)
            allow(line_double).to receive(:new_lineno).and_return(num)
            line_double
          end
          allow(patch).to receive(:added_lines).and_return(lines)
          
          messages = runner.one_message_per_file(lcov_path)
          expect(messages.size).to eq(1)
          expect(messages.first.msg).to include('5–7')
        end
      end

      context 'with a message limit of 2' do
        before do
          allow(runner).to receive(:pronto_messages_per_file_limit).and_return(2)
          
          # Set up lines covering most uncovered areas
          lines = [5, 6, 7, 10, 12, 15, 16, 17, 20, 21].map do |num|
            line_double = instance_double(Pronto::Git::Line)
            allow(line_double).to receive(:new_lineno).and_return(num)
            line_double
          end
          allow(patch).to receive(:added_lines).and_return(lines)
        end

        it 'creates multiple messages per file' do
          messages = runner.one_message_per_file(lcov_path)
          expect(messages.size).to be > 1
          # The default limit is 5, so with 10 lines and a limit of 2 ranges per message,
          # we expect 5 messages (10 lines grouped into 5 ranges, 2 ranges per message)
          expect(messages.size).to be_within(1).of(5)
        end

        it 'limits each message to the specified number of ranges' do
          messages = runner.one_message_per_file(lcov_path)
          
          # Check that no message has more than 2 ranges
          messages.each do |message|
            ranges = message.msg.scan(/\d+–\d+|\d+/).count
            expect(ranges).to be <= 2
          end
        end
      end
    end
  end
end
