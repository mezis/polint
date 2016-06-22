require 'polint/transform'

RSpec.describe Polint::Transform do
  let(:transform) { described_class.new }
  let(:output) { transform.apply(tree) }

  context 'with a headers tree' do
    let(:tree) {
      {
        headers: [
          { quoted_string: [] },
          { name: 'Language', value: 'ar\n' },
          { name: 'MIME-Version', value: '1.0\n' },
          { name: 'Content-Type', value: 'text/plain; charset=UTF-8\n' },
          { name: 'Content-Transfer-Encoding', value: '8bit\n' },
          { name: 'Plural-Forms', value: { nplurals: '6', plural: ' n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 : n%100>=11 ? 4 : 5;\n' } },
          { name: 'X-Generator', value: 'PhraseApp (phraseapp.com)\n' }
        ]
      }
    }
    it {
      expect(output).to eq headers: {
        'Language' => 'ar\n',
        'MIME-Version' => '1.0\n',
        'Content-Type' => 'text/plain; charset=UTF-8\n',
        'Content-Transfer-Encoding' => '8bit\n',
        'Plural-Forms' => { nplurals: 6, plural: ' n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 : n%100>=11 ? 4 : 5;\n' },
        'X-Generator' => 'PhraseApp (phraseapp.com)\n'
      }
    }
  end

  context 'with a plural tree' do
    let(:tree) {
      {
        translation: [
          { flags: [{ flag: 'fuzzy' }] },
          { reference: '../../some_file.rb:34' },
          { reference: '../../some_other_file.rb:283' },
          { msgid: [{ quoted_string: [] }, { quoted_string: 'Hello World' }, { quoted_string: 'Hello Again'}] },
          { msgid_plural: [{ quoted_string: [] }, { quoted_string: 'Hello %{n} Worlds' }, { quoted_string: 'Hello Again'}] },
          { msgstr: [{ index: '0' }, { quoted_string: [] }, { quoted_string: 'Hello World' }, { quoted_string: 'Hello Again'}] },
          { msgstr: [{ index: '1' }, { quoted_string: [] }, { quoted_string: 'Hello %{n} Worlds' }, { quoted_string: 'Hello Again'}] }
        ]
      }
    }
    it {
      expect(output).to eq translation: {
        flags: [:fuzzy],
        references: ['../../some_file.rb:34', '../../some_other_file.rb:283'],
        msgid: { text: "\nHello World\nHello Again" },
        msgid_plural: { text: "\nHello %{n} Worlds\nHello Again" },
        msgstrs: [
          { index: 0, text: "\nHello World\nHello Again" },
          { index: 1, text: "\nHello %{n} Worlds\nHello Again" }
        ]
      }
    }
  end

end
