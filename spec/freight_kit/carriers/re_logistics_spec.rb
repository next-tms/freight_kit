require 'spec_helper'

describe FreightKit::Carriers::RELogistics do
  it_behaves_like 'a carrier'
  it_behaves_like 'a RoadVision platform carrier'

  it { expect(described_class).not_to(be_acts_as_broker) }
  it { expect(described_class).not_to(be_consider_bol_and_pod_documents_same) }
  it { expect(described_class).to(be_create_pickup_implemented) }
  it { expect(described_class).to(be_find_rates_implemented) }
  it { expect(described_class::API[:domain]).to(eq('relmapi.roadvision.com')) }
  it { expect(described_class.legal_name).to(eq('RE Logistics Corp')) }
  it { expect(described_class).not_to(be_pickup_number_is_tracking_number) }
  it { expect(described_class.required_credential_types).to(eq(%i[api])) }
  it { expect(described_class.scac).to(eq('RELM')) }
  it { expect(described_class.us_dot_number).to(eq(3_236_760)) }
  it { expect(described_class.us_mc_number).to(eq(1_015_860)) }
end
