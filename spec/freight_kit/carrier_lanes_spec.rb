require 'spec_helper'

describe FreightKit::Carrier do
  let(:az) { FreightKit::Location.new(country: ActiveUtils::Country.find('US'), postal_code: '85001', province: 'AZ') }
  let(:ca) { FreightKit::Location.new(country: ActiveUtils::Country.find('US'), postal_code: '90001', province: 'CA') }
  let(:carrier) { Class.new(described_class) }
  let(:ks) { FreightKit::Location.new(country: ActiveUtils::Country.find('US'), postal_code: '66101', province: 'KS') }
  let(:nv) { FreightKit::Location.new(country: ActiveUtils::Country.find('US'), postal_code: '89118', province: 'NV') }
  let(:us) { FreightKit::Countries.find_by(iso31661_alpha2: 'US') }

  describe '.matching_lanes' do
    let(:broad_lane) { FreightKit::Lane.new(destination: FreightKit::Territory.new(country: us), origin: FreightKit::Territory.new(country: us)) }
    let(:narrow_lane) do
      FreightKit::Lane.new(
        destination: FreightKit::Territory.new(country: us, region_abbreviation: 'KS'),
        origin: FreightKit::Territory.new(country: us, region_abbreviation: 'CA')
      )
    end

    before { allow(carrier).to(receive(:lanes).and_return([broad_lane, narrow_lane])) }

    it { expect(carrier.matching_lanes(az, ks)).to(eq([broad_lane])) }
    it { expect(carrier.matching_lanes(ca, ks)).to(eq([narrow_lane, broad_lane])) }
  end

  describe '.serve?' do
    it { expect(described_class.serve?(az, ks)).to(be(true)) }
    it { expect(FreightKit::Carriers::A1Express.serve?(az, nv)).to(be(false)) }
    it { expect(FreightKit::Carriers::A1Express.serve?(ca, nv)).to(be(true)) }
    it { expect(FreightKit::Carriers::A1Express.serve?(nv, ca)).to(be(true)) }
    it { expect(FreightKit::Carriers::GSPExpress.serve?(az, ks)).to(be(true)) }
    it { expect(FreightKit::Carriers::GSPExpress.serve?(ks, az)).to(be(false)) }
    it { expect(FreightKit::Carriers::WesternRegionalDeliveryService.serve?(az, ks)).to(be(false)) }
    it { expect(FreightKit::Carriers::WesternRegionalDeliveryService.serve?(ca, ks)).to(be(true)) }

    context 'with territories' do
      let(:territories) { ['AZ', 'CA'].map { |region_abbreviation| FreightKit::Territory.new(country: us, region_abbreviation:) } }

      before { allow(carrier).to(receive(:territories).and_return(territories)) }

      it { expect(carrier.serve?(az, ca)).to(be(true)) }
      it { expect(carrier.serve?(az, ks)).to(be(false)) }
      it { expect(carrier.serve?(ca, az)).to(be(true)) }
    end
  end
end
