# frozen_string_literal: true

RSpec.describe(FreightKit) do
  describe 'VERSION' do
    it { expect(FreightKit::VERSION).to(be_present) }
  end
end
