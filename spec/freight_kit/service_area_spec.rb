require 'spec_helper'

describe FreightKit::ServiceArea do
  let(:country) { FreightKit::Countries.find_by(iso31661_alpha2: 'US') }

  describe '.new' do
    subject(:service_area) { described_class.new(country:) }

    it { is_expected.to(have_attributes(country:, postal_codes: [], regions: [])) }
  end

  describe '#country=' do
    it { expect { described_class.new(country: 'US') }.to(raise_error(ArgumentError)) }
    it { expect { described_class.new(country: nil) }.to(raise_error(ArgumentError)) }
  end
end
