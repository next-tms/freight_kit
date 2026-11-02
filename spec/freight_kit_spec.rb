require 'spec_helper'

describe FreightKit do
  describe '.cache' do
    let(:store) { ActiveSupport::Cache::MemoryStore.new }

    before { described_class.cache = store }

    after { described_class.cache = nil }

    it { expect(described_class.cache).to(be(store)) }
    it { expect(FreightKit::HTTPClient.cache).to(be(store)) }
  end

  describe '.cache by default' do
    it { expect(described_class.cache).to(be_a(ActiveSupport::Cache::MemoryStore)) }
  end
end
