require 'pronto'

module Pronto
  class Rustcov < Runner
    def run
      one_message_per_file(lcov_path)
    end

    private

    def lcov_path
      ENV['PRONTO_RUSTCOV_LCOV_PATH'] || ENV['LCOV_PATH'] || 'target/lcov.info'
    end

    def pronto_files_limit
      ENV['PRONTO_RUSTCOV_FILES_LIMIT']&.to_i || 5
    end

    def pronto_messages_per_file_limit
      ENV['PRONTO_RUSTCOV_MESSAGES_PER_FILE_LIMIT']&.to_i || 5
    end

    def one_message_per_file(lcov_path)
      return [] unless @patches

      lcov = parse_lcov(lcov_path)

      grouped = Hash.new { |h, k| h[k] = [] }

      @patches.sort_by { |patch| -patch.added_lines.count }.take(pronto_files_limit).each do |patch|
        next unless patch.added_lines.any?
        file_path = patch.new_file_full_path.to_s
        uncovered = lcov[file_path]
        next unless uncovered

        patch.added_lines.each do |line|
          if uncovered.include?(line.new_lineno)
            grouped[patch].push(line)
          end
        end
      end

      messages = []

      grouped.each do |patch, lines|
        linenos = lines.map(&:new_lineno).sort
        line_ranges = linenos.chunk_while { |i, j| j == i + 1 }.to_a

        # Group the ranges into batches based on the messages_per_file_limit
        line_ranges.each_slice(pronto_messages_per_file_limit).each_with_index do |ranges_batch, batch_index|
          # Format each range as "start–end" or just the number if it's a single line
          formatted_ranges = ranges_batch.map do |group|
            group.size > 1 ? "#{group.first}–#{group.last}" : group.first.to_s
          end

          message_text = "⚠️ Test coverage is missing for lines: #{formatted_ranges.join(', ')}"

          # Find the first line in this batch for the message
          first_line_in_batch = lines.find { |line| line.new_lineno == ranges_batch.first.first }

          messages << Pronto::Message.new(
            patch.new_file_path,
            first_line_in_batch,
            :warning,
            message_text,
            nil,
            self.class
          )
        end
      end

      messages
    end

    def parse_lcov(path)
      uncovered = Hash.new { |h, k| h[k] = [] }
      file = nil

      begin
        File.foreach(path) do |line|
          case line
          when /^SF:(.+)/
            file = File.expand_path($1.strip)
          when /^DA:(\d+),0$/
            uncovered[file] << $1.to_i if file
          when /^end_of_record/
            file = nil
          end
        end
      rescue Errno::ENOENT
        # File not found, raise a more informative error
        fail "LCOV file not found at #{path}. Make sure your Rust tests were run with coverage enabled."
      end

      uncovered
    end
  end
end
