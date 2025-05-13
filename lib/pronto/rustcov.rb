require 'pronto'

module Pronto
  class Rustcov < Runner
    def run
      return [] unless @patches

      lcov = parse_lcov('target/lcov.info')
      messages = []

      @patches.each do |patch|
        next unless patch.added_lines.any?
        file_path = patch.new_file_full_path.to_s
        uncovered = lcov[file_path]
        next unless uncovered

        patch.added_lines.each do |line|
          if uncovered.include?(line.new_lineno)
            messages << Message.new(
              patch.new_file_path,
              line,
              :warning,
              "⚠️ Tests are missing.",
              nil,
              self.class
            )
          end
        end
      end

      messages
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
