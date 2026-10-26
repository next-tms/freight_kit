require 'spec_helper'

describe FreightKit::Carriers::BestOverniteExpress do
  it_behaves_like 'a carrier'
  it_behaves_like 'a The Great Information Factory platform carrier'

  it { expect(described_class).not_to(be_acts_as_broker) }
  it { expect(described_class).not_to(be_bol_requires_tracking_number) }
  it { expect(described_class).not_to(be_consider_bol_and_pod_documents_same) }
  it { expect(described_class).to(be_create_pickup_implemented) }
  it { expect(described_class).to(be_find_rates_implemented) }
  it { expect(described_class).not_to(be_find_rates_with_declared_value) }
  it { expect(described_class).not_to(be_pickup_number_is_tracking_number) }
  it { expect(described_class.required_credential_types).to(eq(%i[api])) }
end
