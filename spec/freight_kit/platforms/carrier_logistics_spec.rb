require 'spec_helper'

describe FreightKit::Platforms::CarrierLogistics do
  it { expect(described_class.required_credential_types).to(eq(%i[api])) }
  it { expect(described_class.requirements).to(eq(%i[credentials tariff])) }
  it { expect(described_class::API[:domain]).to(eq('tracking.carrierlogistics.com')) }
  it { expect(described_class::EVENTS.dig(:types, :delivered)).to(eq('delivered')) }
end
