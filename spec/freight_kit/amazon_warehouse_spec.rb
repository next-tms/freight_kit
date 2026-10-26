require 'spec_helper'

describe FreightKit::AmazonWarehouse do
  def build_location(address1:, postal_code:)
    FreightKit::Location.new(
      address1:,
      city: 'Aurora',
      country: ActiveUtils::Country.find('US'),
      postal_code:,
      province: 'CO'
    )
  end

  describe '.find' do
    subject(:warehouse) { described_class.find(location) }

    context 'with an abbreviated address of a warehouse' do
      let(:location) { build_location(address1: '22205 E. 19th Ave.', postal_code: '80019') }

      it { expect(warehouse[:ref]).to(eq('DEN2')) }
    end

    context 'with a ZIP+4 postal code' do
      let(:location) { build_location(address1: '22205 East 19th Avenue', postal_code: '80019-1234') }

      it { expect(warehouse[:ref]).to(eq('DEN2')) }
    end

    context 'with a warehouse address in a different postal code' do
      let(:location) { build_location(address1: '22205 East 19th Avenue', postal_code: '80011') }

      it { is_expected.to(be_nil) }
    end

    context 'with a different house number' do
      let(:location) { build_location(address1: '22207 East 19th Avenue', postal_code: '80019') }

      it { is_expected.to(be_nil) }
    end

    context 'without an address' do
      let(:location) { build_location(address1: nil, postal_code: '80019') }

      it { is_expected.to(be_nil) }
    end
  end
end
