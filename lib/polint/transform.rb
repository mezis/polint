require 'parslet'

module Polint
  class Transform < Parslet::Transform

    rule(flag: simple(:f)) { f.to_sym }

    rule(quoted_string: simple(:qs)) { qs }
    rule(quoted_string: sequence(:qs)) { '' } # empty string is parsed as []

    rule(name: simple(:k), value: simple(:v)) { [k.to_s, v.to_s] }
    rule(name: simple(:k), value: subtree(:v)) { [k.to_s, v] }
    rule(nplurals: simple(:n), plural: simple(:p)) { { nplurals: n.to_i, plural: p } }
    rule(headers: subtree(:items)) do
      items.shift if items.first == ''
      { headers: items.to_h }
    end

    rule(msgid: sequence(:items)) { { msgid: { text: items.join } } }
    rule(msgid_plural: sequence(:items)) { { msgid_plural: { text: items.join } } }
    rule(msgstr: subtree(:items)) do
      msgstr = {}
      msgstr[:index] = items.shift[:index].to_i if items.first.is_a?(Hash)
      msgstr[:text] = items.join
      { msgstr: msgstr }
    end

    rule(translation: subtree(:items)) do
      translation = {
        flags: [],
        references: [],
        comments: [],
        msgid: {},
        msgid_plural: {},
        msgstrs: []
      }
      items.each do |hash|
        k, v = hash.to_a.first
        case k
        when :flags then translation[:flags] |= v
        when :reference then translation[:references] << v
        when :comment then translation[:comments] << v
        when :msgid, :msgid_plural then translation[k] = v
        when :msgstr then translation[:msgstrs] << v
        end
      end
      { translation: translation }
    end

    rule(file: subtree(:items)) do
      file = {
        headers: {},
        translations: []
      }
      items.each do |hash|
        k, v = hash.to_a.first
        case k
        when :headers then file[:headers] = v
        when :translation then file[:translations] << v
        end
      end
      file
    end

  end
end
