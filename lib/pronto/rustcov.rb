require 'pronto'

module Pronto
  class Rustcov < Runner
    def run
      if ENV['PRONTO_RUSTCOV_URL']
        one_message_per_file_markdown('target/lcov.info', ENV['PRONTO_RUSTCOV_URL'])
      else
        one_message_per_file('target/lcov.info')
      end
    end

    def one_message_per_file_markdown(lcov_path, base_url)
      base_url = base_url.delete_suffix('/')

      return [] unless @patches

      lcov = parse_lcov(lcov_path)

      grouped = Hash.new { |h, k| h[k] = [] }

      @patches.each do |patch|
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
                        .map { |group| group.size > 1 ? "#{group.first}–#{group.last}" : group.first.to_s }

        url = "#{base_url}/#{patch.new_file_path}.html#L#{linenos.first}"
        first_range_link = "[#{ranges.first}](#{url})"
        message_text = "⚠️ Test coverage is missing for lines: #{first_range_link}, #{ranges[1..].join(', ')}"

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

    def one_message_per_file(lcov_path)
      return [] unless @patches

      lcov = parse_lcov(lcov_path)

      grouped = Hash.new { |h, k| h[k] = [] }

      @patches.each do |patch|
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
