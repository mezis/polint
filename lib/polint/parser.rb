require 'parslet'

module Polint
  class Parser < Parslet::Parser

    rule(:endl) { str("\n").maybe }
    rule(:sp) { str(' ') }
    rule(:htab) { str("\t") }
    rule(:wsp) { sp | htab }
    rule(:lwsp) { wsp.repeat }
    rule(:tcase) { match(/[A-Z]/).repeat(1) >> match(/[a-z]/).repeat }
    rule(:blank_line) { endl }

    rule(:quote) { str('"') }
    rule(:quoted_char) { match(/[^"]/) }
    rule(:quoted_pair) { str('\\') >> quote }
    rule(:quoted_string) { quote >> (quoted_pair | quoted_char).repeat.as(:quoted_string) >> quote >> lwsp }
    rule(:quoted_strings) { (quoted_string >> endl).repeat(1) }

    rule(:header_sep) { str(':') >> lwsp }
    rule(:header_name) { (tcase >> (str('-') >> tcase).repeat).as(:name) >> header_sep }
    rule(:header_value) { match(/[^\n"]/).repeat.as(:value) }
    rule(:raw_header) { header_name >> header_value }
    rule(:nplurals) { str('nplurals=') >> match(/[0-9]/).repeat.as(:nplurals) >> str(';') >> lwsp }
    rule(:plural) { str('plural=') >> match(/[^\n"]/).repeat.as(:plural) }
    rule(:plural_forms_header) { str('Plural-Forms').as(:name) >> header_sep >> (nplurals >> plural).as(:value) }
    rule(:unquoted_header) { plural_forms_header | raw_header }
    rule(:header) { quote >> unquoted_header >> quote >> lwsp }
    rule(:header_lines) { (header >> endl).repeat(1) }
    rule(:headers) { str('msgid') >> lwsp >> quote >> quote >> endl >> str('msgstr') >> lwsp >> ((quoted_string >> endl).maybe >> header_lines).as(:headers) >> blank_line }

    rule(:start_comment) { str('#') }
    rule(:flag) { str(',') >> lwsp >> match(/[a-z\-]/).repeat(1).as(:flag) >> lwsp }
    rule(:flag_comment) { start_comment >> flag.repeat(1).as(:flags) >> endl }
    rule(:reference_comment) { start_comment >> str(':') >> lwsp >> match(/[^\n]/).repeat.as(:reference) >> endl }
    rule(:unparsed_comment) { start_comment >> match(/[^~]/) >> lwsp >> match(/[^\n]/).repeat.as(:comment) >> endl }
    rule(:comment) { flag_comment | reference_comment | unparsed_comment }
    rule(:comments) { comment.repeat }

    rule(:msgid) { str('msgid') >> lwsp >> quoted_strings.as(:msgid) }
    rule(:msgid_plural) { str('msgid_plural') >> lwsp >> quoted_strings.as(:msgid_plural) }

    rule(:index) { str('[') >> match(/[0-9]/).repeat(1).as(:index) >> str(']') }
    rule(:msgstr) { str('msgstr') >> (index.maybe >> lwsp >> quoted_strings).as(:msgstr) }

    rule(:translation) { (comments >> msgid >> msgid_plural.repeat(0, 1) >> msgstr.repeat(1)).as(:translation) >> blank_line }
    rule(:translations) { translation.repeat }

    rule(:obsolete_line) { start_comment >> str('~') >> lwsp >> match(/[^\n]/).repeat >> endl }
    rule(:obsolete_translation) { (comment.repeat >> obsolete_line.repeat(1).as(:text)).as(:obsolete_translation) >> blank_line }
    rule(:obsolete_translations) { obsolete_translation.repeat }

    rule(:file) { (headers >> translations >> obsolete_translations).as(:file) }
    root(:file)

  end
end
