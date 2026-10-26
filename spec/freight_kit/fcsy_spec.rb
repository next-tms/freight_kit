require 'spec_helper'

describe FreightKit::FCSY do
  subject(:carrier) { described_class.allocate }

  describe '#build_calculated_accessorials' do
    subject(:accessorials) { carrier.build_calculated_accessorials(shipment) }

    let(:package) do
      FreightKit::Package.new(480, { length: 48, width: 40, height: 40 }, :pallet, units: :imperial, quantity: 1)
    end
    let(:shipment) { FreightKit::Shipment.new(destination:, packages: [package]) }

    context 'with an Amazon warehouse destination' do
      let(:destination) do
        FreightKit::Location.new(
          address1: '22205 E 19th Ave',
          city: 'Aurora',
          country: ActiveUtils::Country.find('US'),
          postal_code: '80019',
          province: 'CO'
        )
      end

      it { is_expected.to(include('AMAZON')) }
    end

    context 'with another destination' do
      let(:destination) do
        FreightKit::Location.new(
          address1: '7200 Franklin Ave',
          city: 'Los Angeles',
          country: ActiveUtils::Country.find('US'),
          postal_code: '90046',
          province: 'CA'
        )
      end

      it { is_expected.not_to(include('AMAZON')) }
    end
  end
end
