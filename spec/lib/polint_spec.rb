require 'polint'

RSpec.describe Polint::Checker do

  Dir.glob(File.join(__dir__, '..', 'data', '*-valid.po')) do |file|
    context "#{File.basename(file, '.po').split('-').join(' ')}" do
      let(:checker) { described_class.new(file) }

      it 'has no errors' do
        expect(checker.run).to eq 0
      end
    end
  end

end
