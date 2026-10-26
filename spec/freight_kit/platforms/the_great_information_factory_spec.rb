require 'spec_helper'

describe FreightKit::Platforms::TheGreatInformationFactory do
  it { expect(described_class.required_credential_types).to(eq(%i[api])) }
  it { expect(described_class.requirements).to(eq(%i[credentials tariff])) }
  it { expect(described_class.services).to(eq(%i[standard])) }
  it { expect(described_class::API).not_to(have_key(:domain)) }
  it { expect(described_class::EVENTS.dig(:types, :delivered)).to(eq('delivered')) }
end
