require 'spec_helper'

describe FreightKit::Territory do
  let(:az) { FreightKit::Location.new(country: ActiveUtils::Country.find('US'), postal_code: '85001-1234', province: 'AZ') }
  let(:us) { FreightKit::Countries.find_by(iso31661_alpha2: 'US') }

  describe '#country=' do
    it { expect { described_class.new(country: nil) }.to(raise_error(ArgumentError)) }
  end

  describe '#include?' do
    it { expect(described_class.new(country: FreightKit::Countries.find_by(iso31661_alpha2: 'CA'))).not_to(include(az)) }
    it { expect(described_class.new(country: us)).to(include(az)) }
    it { expect(described_class.new(country: us, postal_codes: ['850'])).to(include(az)) }
    it { expect(described_class.new(country: us, postal_codes: ['90001', '90002'])).not_to(include(az)) }
    it { expect(described_class.new(country: us, region_abbreviation: 'AZ')).to(include(az)) }
    it { expect(described_class.new(country: us, region_abbreviation: 'CA')).not_to(include(az)) }
  end

  describe '#postal_codes' do
    it { expect(described_class.new(country: us).postal_codes).to(eq([])) }
  end

  describe '#specificity' do
    it { expect(described_class.new(country: us).specificity).to(eq(0)) }
    it { expect(described_class.new(country: us, postal_codes: ['850'], region_abbreviation: 'AZ').specificity).to(eq(2)) }
    it { expect(described_class.new(country: us, region_abbreviation: 'AZ').specificity).to(eq(1)) }
  end
end
