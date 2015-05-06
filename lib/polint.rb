# coding: utf-8
require 'polint/version'
require 'singleton'

module Polint
  class BlackHole
    include Singleton

    def method_missing(*args)
      nil
    end
  end

  class Checker
    AttributeRe = /
      %\{ [^\}]+ \}  |     # Ruby Gettext
      %\( [^\)]+ \)[sd] |  # Javascript sprintf
      \{\{ [^\}] \}\}      # Liquid
    /x
    TA = Term::ANSIColor

    def initialize(pofile)
      @pofile = pofile
    end

    def run
      @verbose = !!ENV["VERBOSE"]
      @errors  = 0
      @fuzzies = 0

      lint_po
      parse_data annotate_and_load_po

      total_errors = @errors + @fuzzies
      $stderr.puts "#{@errors} warnings, #{@fuzzies} fuzzies." if total_errors > 0
      return total_errors
    end

  private

    def term
      @term ||= ENV['NOCOLOR'] ? BlackHole.instance : Term::ANSIColor
    end

    def success
      $? == 0
    end

    def die(message)
      raise StandardError.new(message)
    end

    # Check the PO file for syntactical correctness
    def lint_po
      system %Q{msgcat "#{@pofile}" > /dev/null}
      success or die "The PO file '#{@pofile}' is broken, aborting."
    end

    # Load the PO file, annotate keys with original line numbers, and unwrap lines.
    def annotate_and_load_po
      data = []
      header_seen = false
      File.open(@pofile).each_with_index do |line,index|
        if line =~ /^msgid\s+"(.*)"$/
          if header_seen
            data << %Q{msgid "#{index+1}:#{$1}"\n}
          else
            data << line
            header_seen = true
          end
        else
          data << line
        end
      end

      IO.popen("msgcat --no-wrap -",'r+') do |io|
        io.write data.join
        io.flush
        io.close_write
        data = io.read.split(/\n/)
      end
      success and return data
      die "Error while loading the PO file '#{@pofile}', aborting."
    end

    def parse_data(lines)
      current = []
      context = []
      next_is_fuzzy = false

      lines.each do |line|
        case line

        when /^#, fuzzy/
          next_is_fuzzy = true

        when /^#: (.*)/
          context << $1

        when /^(msgid|msgid_plural)\s+"(.*)"$/
          current << $2

        when /^(msgstr(?:\[([01])\])?)\s+"(.*)"$/
          index = $2.to_i # $2 will be nil for non-plural, so index will be 0
          check_pair(current[index], $3, context, next_is_fuzzy)

        else
          current = []
          context = []
          next_is_fuzzy = false
        end
      end
    end

    # Check for errors in a key/translation pair.
    def check_pair(key, val, contexts, is_fuzzy)
      return if key.nil? || val.nil?

      is_empty = key.strip.length > 0 && val.strip.length == 0

      attrs_key = key.scan(AttributeRe).sort.uniq
      attrs_val = val.scan(AttributeRe).sort.uniq

      not_in_key = attrs_val - attrs_key
      not_in_val = attrs_key - attrs_val

      return unless not_in_key.any? || not_in_val.any? || is_empty || is_fuzzy

      @errors  += 1 if not_in_val.any? || not_in_key.any? || is_empty
      @fuzzies += 1 if is_fuzzy

      if key =~ /(\d+):(.*)/
        lineno = $1
        file_and_line = "#{@pofile}:#{$1}:"
        key = $2
      else
        lineno = nil
        file_and_line = "#{@pofile}:"
      end

      if is_empty
        puts "#{file_and_line}#{term.red} Error: translated string empty.#{term.clear}"
      elsif not_in_key.any?
        not_in_key.each do |name|
          puts "#{file_and_line}#{term.red} Error: #{name} absent from reference string.#{term.clear}"
        end
      elsif not_in_val.any?
        not_in_val.each do |name|
          puts "#{file_and_line}#{term.yellow} Warning: #{name} absent from translated string.#{term.clear}"
        end
      elsif is_fuzzy
        puts "#{file_and_line}#{term.yellow} Warning: translation is fuzzy.#{term.clear}"
      end

      if @verbose
        contexts.each do |context|
          puts "#{term.blue}CONTEXT:#{term.clear} #{context}"
        end
        puts "#{term.blue}KEY:#{term.clear} #{key}"
        puts "#{term.blue}TRN:#{term.clear} #{val}"
        puts "–" * 80
      end
    end
  end
end
