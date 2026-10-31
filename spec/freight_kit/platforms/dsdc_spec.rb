require 'spec_helper'

describe FreightKit::Platforms::DSDC do
  it { expect(described_class.required_credential_types).to(eq(%i[api])) }
  it { expect(described_class::API).not_to(have_key(:domain)) }
  it { expect(described_class::API[:endpoints].keys).to(match_array(described_class::API[:methods].keys)) }

  describe '#build_url' do
    subject(:carrier) { carrier_class.new(FreightKit::Credential.new(type: :api, username: 'user', password: 'pass')) }

    let(:carrier_class) do
      Class.new(described_class) do
        const_set(:API, FreightKit::Platforms::DSDC::API.deep_merge(domain: 'api.example.com', prefix: '/dsdc'))
      end
    end

    it { expect(carrier.__send__(:build_url, :create_bol)).to(eq('https://api.example.com/dsdc/bol/v1/app/')) }
    it { expect(carrier.__send__(:build_url, :track, pro: '123 45')).to(eq('https://api.example.com/dsdc/shipment/pro/123%2045/verified')) }
  end
end
