require 'pronto'

module Pronto
  class Rustcov < Runner
    def run
      one_message_per_file('target/lcov.info')
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

      grouped.map do |patch, lines|
        linenos = lines.map(&:new_lineno).sort
        ranges = linenos.chunk_while { |i, j| j == i + 1 }
                        .take(pronto_messages_per_file_limit)
                        .map { |group| group.size > 1 ? "#{group.first}–#{group.last}" : group.first.to_s }

        message_text = "⚠️ Test coverage is missing for lines: #{ranges.join(', ')}"

        # Attach the message to the first uncovered line
        Pronto::Message.new(
          patch.new_file_path,
          lines.first,
          :warning,
          message_text,
          nil,
          self.class
        )
      end
    end

    private

    def parse_lcov(path)
      uncovered = Hash.new { |h, k| h[k] = [] }
      file = nil

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

      uncovered
    end
  end
end
