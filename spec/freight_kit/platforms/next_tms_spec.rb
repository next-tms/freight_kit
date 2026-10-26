require 'spec_helper'

describe FreightKit::Platforms::NextTMS do
  it { expect(described_class.required_credential_types).to(eq(%i[api])) }
  it { expect(described_class::API).not_to(have_key(:domain)) }
  it { expect(described_class::API[:prefix]).to(eq('/api/v1')) }
end
