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

      grouped = group_patches(@patches, lcov)

      build_messages(grouped)
    end

    def group_patches(patches, lcov)
      grouped = Hash.new { |h, k| h[k] = [] }

      patches.each do |patch|
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

      grouped.sort_by { |_, lines| -lines.count }.take(pronto_files_limit)
    end

    def build_messages(grouped)
      messages = []

      grouped.each do |patch, lines|
        linenos = lines.map(&:new_lineno).sort
        line_ranges = linenos.chunk_while { |i, j| j == i + 1 }.to_a

        best_ranges = line_ranges.sort_by { |range| [-range.size, range.first] }.take(pronto_messages_per_file_limit)

        # If we have a message per file limit of N, then create N individual messages
        # We'll take each range and create a separate message for it, up to the limit
        best_ranges.each do |range|
          message_text = format_message_text(range)

          # Find the first line in this range for the message
          first_line_in_range = lines.find { |line| line.new_lineno == range.first }

          messages << Pronto::Message.new(
            patch.new_file_path,
            first_line_in_range,
            :warning,
            message_text,
            nil,
            self.class
          )
        end
      end

      messages
    end

    def format_message_text(range)
      if range.size > 1
        "⚠️ Test coverage is missing for lines: #{range.first}–#{range.last}"
      else
        "⚠️ Test coverage is missing"
      end
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
