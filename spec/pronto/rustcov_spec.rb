# frozen_string_literal: true

RSpec.describe Pronto::Rustcov do
  subject(:runner) { described_class.new(patches) }
  let(:patches) { [] }

  describe '#pronto_files_limit' do
    it 'defaults to 5' do
      expect(runner.pronto_files_limit).to eq(5)
    end

    it 'respects environment variable' do
      allow(ENV).to receive(:[]).with('PRONTO_RUSTCOV_FILES_LIMIT').and_return('10')
      expect(runner.pronto_files_limit).to eq(10)
    end
  end

  describe '#pronto_messages_per_file_limit' do
    it 'defaults to 5' do
      expect(runner.pronto_messages_per_file_limit).to eq(5)
    end

    it 'respects environment variable' do
      allow(ENV).to receive(:[]).with('PRONTO_RUSTCOV_MESSAGES_PER_FILE_LIMIT').and_return('3')
      expect(runner.pronto_messages_per_file_limit).to eq(3)
    end
  end
end
