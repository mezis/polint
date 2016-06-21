# coding: utf-8
require 'polint/version'
require 'polint/parser'
require 'polint/transform'
require 'term/ansicolor'
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

    def error(key, val, contexts, message)
      log key, val, contexts, "Error: #{message}", :red
    end

    def warn(key, val, contexts, message)
      log key, val, contexts, "Warning: #{message}", :yellow
    end

    def log(key, val, contexts, message, color)
      if key =~ /(\d+):(.*)/
        lineno = $1
        file_and_line = "#{@pofile}:#{$1}:"
        key = $2
      else
        lineno = nil
        file_and_line = "#{@pofile}:"
      end
      puts "#{file_and_line}#{term.public_send(color)} #{message}.#{term.clear}"
      if @verbose
        contexts.each do |context|
          puts "#{term.blue}CONTEXT:#{term.clear} #{context}"
        end
        puts "#{term.blue}KEY:#{term.clear} #{key}"
        puts "#{term.blue}TRN:#{term.clear} #{val}"
        puts "–" * 80
      end
    end

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
        data = io.read
      end
      success and return data
      die "Error while loading the PO file '#{@pofile}', aborting."
    end

    def parse_data(data)
      return if data.nil? || data.empty?

      tree = Polint::Parser.new.parse(data)
      tree = Polint::Transform.new.apply(tree)

      die 'No Plural-Forms header found' unless tree[:headers].key?('Plural-Forms')
      nplurals = tree[:headers]['Plural-Forms'][:nplurals]

      tree[:translations].each do |translation|
        msgid, msgid_plural = translation[:msgid][:text], translation[:msgid_plural][:text]
        contexts = translation[:references]
        fuzzy = translation[:flags].include?(:fuzzy)

        if msgid_plural.nil?
          if translation[:msgstrs].size != 1
            error msgid, nil, contexts, "#{translation[:msgstrs].size} plurals found but none expected"
            @errors += 1
          end

          check_pair(msgid, translation[:msgstrs][0][:text], translation[:references], fuzzy)
        else
          if translation[:msgstrs].size != nplurals
            error msgid, nil, contexts, "#{translation[:msgstrs].size} plurals found but #{nplurals} expected"
            @errors += 1
          end

          plural_attr = (msgid_plural.scan(AttributeRe).uniq - msgid.scan(AttributeRe).uniq).first
          translation[:msgstrs].each do |msgstr|
            val = msgstr[:text]
            msgid_check = val.scan(AttributeRe).include?(plural_attr) ? msgid_plural : msgid
            check_pair(msgid_check, val, contexts, fuzzy)
          end
        end
      end
    rescue Parslet::ParseFailed => e
      die e.cause.ascii_tree
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

      if is_empty
        error key, val, contexts, "translated string empty"
      elsif not_in_key.any?
        not_in_key.each do |name|
          error key, val, contexts, "#{name} absent from reference string"
        end
      elsif not_in_val.any?
        not_in_val.each do |name|
          warn key, val, contexts, "#{name} absent from translated string"
        end
      elsif is_fuzzy
        warn key, val, contexts, "translation is fuzzy"
      end
    end
  end
end
