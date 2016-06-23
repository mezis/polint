require 'polint/parser'

RSpec.describe Polint::Parser do
  let(:parser) { described_class.new }
  let(:rule) { :translation }
  let(:line) { '' }
  let(:tree) { parser.send(rule).parse(line) }

  describe 'rule(:quoted_string)' do
    let(:rule) { :quoted_string }

    context 'when matching a simple string' do
      let(:line) { '"Hello World"' }
      it { expect(tree).to eq quoted_string: 'Hello World' }
    end

    context 'when matching a string with embedded quotes' do
      let(:line) { '"Hello \\"my\\" World"' }
      it { expect(tree).to eq quoted_string: 'Hello \\"my\\" World' }
    end
  end

  describe 'rule(:headers)' do
    let(:rule) { :headers }
    let(:line) { lines.join("\n") }

    context 'when matching a plural forms header' do
      let(:lines) {
        [
          'msgid ""',
          'msgstr ""',
          '"Language: ar\n"',
          '"MIME-Version: 1.0\n"',
          '"Content-Type: text/plain; charset=UTF-8\n"',
          '"Content-Transfer-Encoding: 8bit\n"',
          '"Plural-Forms: nplurals=6; plural= n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 : n%100>=11 ? 4 : 5;\n"',
          '"X-Generator: PhraseApp (phraseapp.com)\n"'
        ]
      }
      it {
        expect(tree).to eq headers: [
          { quoted_string: [] },
          { name: 'Language', value: 'ar\n' },
          { name: 'MIME-Version', value: '1.0\n' },
          { name: 'Content-Type', value: 'text/plain; charset=UTF-8\n' },
          { name: 'Content-Transfer-Encoding', value: '8bit\n' },
          { name: 'Plural-Forms', value: { nplurals: '6', plural: ' n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 : n%100>=11 ? 4 : 5;\n' } },
          { name: 'X-Generator', value: 'PhraseApp (phraseapp.com)\n' }
        ]
      }
    end

    context 'when matching an unquoted header' do
      let(:line) { 'Plural-Forms: nplurals=6; plural= n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 : n%100>=11 ? 4 : 5;\n' }
      it { expect{ tree }.to raise_error Parslet::ParseFailed }
    end
  end

  describe 'rule(:flag_comment)' do
    let(:rule) { :flag_comment }

    context 'when matching a fuzzy comment' do
      let(:line) { '#, fuzzy' }
      it { expect(tree).to eq flags: [{ flag: 'fuzzy' }] }
    end

    context 'when matching a multi-flag comment' do
      let(:line) { '#, java-format, fuzzy' }
      it { expect(tree).to eq flags: [{ flag: 'java-format' }, { flag: 'fuzzy' }] }
    end

    context 'when matching a non-flags comment' do
      let(:line) { '#: ../../some_file.rb:34' }
      it { expect{ tree }.to raise_error Parslet::ParseFailed }
    end
  end

  describe 'rule(:reference_comment)' do
    let(:rule) { :reference_comment }

    context 'when matching a reference comment' do
      let(:line) { '#: ../../some_file.rb:34' }
      it { expect(tree).to eq reference: '../../some_file.rb:34' }
    end

    context 'when matching a non-reference comment' do
      let(:line) { '#, fuzzy' }
      it { expect{ tree }.to raise_error Parslet::ParseFailed }
    end
  end

  describe 'rule(:unparsed_comment)' do
    let(:rule) { :unparsed_comment }

    context 'when matching a translator comment' do
      let(:line) { '# no semantics here' }
      it { expect(tree).to eq comment: 'no semantics here' }
    end

    context 'when matching an extracted comment' do
      let(:line) { '#. no semantics here' }
      it { expect(tree).to eq comment: 'no semantics here' }
    end

    context 'when matching a previous translation comment' do
      let(:line) { '#| no semantics here' }
      it { expect(tree).to eq comment: 'no semantics here' }
    end

    context 'when matching an obsolete translation' do
      let(:line) { '#~ obsolete things go here' }
      it { expect{ tree }.to raise_error Parslet::ParseFailed }
    end
  end

  describe 'rule(:msgid)' do
    let(:rule) { :msgid }

    context 'when matching a single-line msgid' do
      let(:line) { 'msgid "Hello World"' }
      it { expect(tree).to eq msgid: [{ quoted_string: 'Hello World' }] }
    end

    context 'when matching a multi-line msgid' do
      let(:line) { %{msgid ""\n"Hello World"\n"Hello Again"} }
      it { expect(tree).to eq msgid: [{ quoted_string: [] }, { quoted_string: 'Hello World' }, { quoted_string: 'Hello Again'}] }
    end

    context 'when matching a msgid with embedded quotes' do
      let(:line) { 'msgid "Hello \\"my\\" World"' }
      it { expect(tree).to eq msgid: [{ quoted_string: 'Hello \\"my\\" World' }] }
    end

    context 'when matching an unquoted msgid' do
      let(:line) { 'msgid Unquoted String' }
      it { expect{ tree }.to raise_error Parslet::ParseFailed }
    end
  end

  describe 'rule(:msgid_plural)' do
    let(:rule) { :msgid_plural }

    context 'when matching a single-line msgid_plural' do
      let(:line) { 'msgid_plural "Hello %{n} Worlds"' }
      it { expect(tree).to eq msgid_plural: [{ quoted_string: 'Hello %{n} Worlds' }] }
    end

    context 'when matching a multi-line msgid_plural' do
      let(:line) { %{msgid_plural ""\n"Hello %{n} Worlds"\n"Hello Again"} }
      it { expect(tree).to eq msgid_plural: [{ quoted_string: [] }, { quoted_string: 'Hello %{n} Worlds' }, { quoted_string: 'Hello Again'}] }
    end

    context 'when matching an unquoted msgid_plural' do
      let(:line) { 'msgid_plural Unquoted String' }
      it { expect{ tree }.to raise_error Parslet::ParseFailed }
    end
  end

  describe 'rule(:msgstr)' do
    let(:rule) { :msgstr }

    context 'when matching a single-line msgstr' do
      let(:line) { 'msgstr "Hello World"' }
      it { expect(tree).to eq msgstr: [{ quoted_string: 'Hello World' }] }
    end

    context 'when matching a single-line msgstr with an index' do
      let(:line) { 'msgstr[3] "Hello World"' }
      it { expect(tree).to eq msgstr: [{ index: '3' }, { quoted_string: 'Hello World' }] }
    end

    context 'when matching a multi-line msgstr' do
      let(:line) { %{msgstr ""\n"Hello World"\n"Hello Again"} }
      it { expect(tree).to eq msgstr: [{ quoted_string: [] }, { quoted_string: 'Hello World' }, { quoted_string: 'Hello Again'}] }
    end

    context 'when matching a multi-line msgstr with an index' do
      let(:line) { %{msgstr[1] ""\n"Hello World"\n"Hello Again"} }
      it { expect(tree).to eq msgstr: [{ index: '1' }, { quoted_string: [] }, { quoted_string: 'Hello World' }, { quoted_string: 'Hello Again'}] }
    end

    context 'when matching an unquoted msgstr' do
      let(:line) { 'msgstr Unquoted String' }
      it { expect{ tree }.to raise_error Parslet::ParseFailed }
    end
  end

  describe 'rule(:translation)' do
    let(:rule) { :translation }
    let(:line) { lines.join("\n") }

    context 'when matching a singular single-line msgstr with comments' do
      let(:lines) {
        [
          '#, fuzzy',
          '#: ../../some_file.rb:34',
          'msgid "Hello World"',
          'msgstr "Hello World"'
        ]
      }
      it {
        expect(tree).to eq translation: [
          { flags: [{ flag: 'fuzzy' }] },
          { reference: '../../some_file.rb:34' },
          { msgid: [{ quoted_string: 'Hello World' }] },
          { msgstr: [{ quoted_string: 'Hello World' }] }
        ]
      }
    end

    context 'when matching a plural single-line msgstr with comments' do
      let(:lines) {
        [
          '#, fuzzy',
          '#: ../../some_file.rb:34',
          'msgid "Hello World"',
          'msgid_plural "Hello %{n} Worlds"',
          'msgstr[0] "Hello World"',
          'msgstr[1] "Hello %{n} Worlds"'
        ]
      }
      it {
        expect(tree).to eq translation: [
          { flags: [{ flag: 'fuzzy' }] },
          { reference: '../../some_file.rb:34' },
          { msgid: [{ quoted_string: 'Hello World' }] },
          { msgid_plural: [{ quoted_string: 'Hello %{n} Worlds' }] },
          { msgstr: [{ index: '0' }, { quoted_string: 'Hello World' }] },
          { msgstr: [{ index: '1' }, { quoted_string: 'Hello %{n} Worlds' }] }
        ]
      }
    end

    # TODO: Multiline strings and negative cases
  end

  describe 'rule(:translations)' do
    let(:rule) { :translations }
    let(:line) { lines.join("\n") }

    context 'when matching multiple translations' do
      let(:lines) {
        [
          '#, fuzzy',
          '#: ../../some_file.rb:34',
          'msgid "Hello World"',
          'msgstr "Hello World"',
          '',
          '#, fuzzy',
          '#: ../../some_file.rb:34',
          'msgid "Hello World"',
          'msgid_plural "Hello %{n} Worlds"',
          'msgstr[0] "Hello World"',
          'msgstr[1] "Hello %{n} Worlds"'
        ]
      }
      it {
        expect(tree).to eq [
          {
            translation: [
              { flags: [{ flag: 'fuzzy' }] },
              { reference: '../../some_file.rb:34' },
              { msgid: [{ quoted_string: 'Hello World' }] },
              { msgstr: [{ quoted_string: 'Hello World' }] }
            ]
          },
          {
            translation: [
              { flags: [{ flag: 'fuzzy' }] },
              { reference: '../../some_file.rb:34' },
              { msgid: [{ quoted_string: 'Hello World' }] },
              { msgid_plural: [{ quoted_string: 'Hello %{n} Worlds' }] },
              { msgstr: [{ index: '0' }, { quoted_string: 'Hello World' }] },
              { msgstr: [{ index: '1' }, { quoted_string: 'Hello %{n} Worlds' }] }
            ]
          }
        ]
      }
    end
  end

  describe 'rule(:obsolete_translation)' do
    let(:rule) { :obsolete_translation }
    let(:line) { lines.join("\n") }

    context 'when matching a singular single-line msgstr with comments' do
      let(:lines) {
        [
          '# comment on obsolete translation',
          '#~ msgid "Hello World"',
          '#~ msgstr "Hello World"'
        ]
      }
      it {
        expect(tree).to eq obsolete_translation: [
          { comment: 'comment on obsolete translation' },
          { text: %{#~ msgid "Hello World"\n#~ msgstr "Hello World"} }
        ]
      }
    end
  end

end
