shared_examples 'a platform carrier' do |platform|
  it { expect(described_class.superclass).to(eq(platform)) }

  describe 'API' do
    subject(:api) { described_class::API }

    it { expect(api[:domain]).to(be_present) }
    it { expect(api.keys).to(include(*platform::API.keys)) }
  end
end

shared_examples 'a Carrier Logistics platform carrier' do
  it_behaves_like 'a platform carrier', FreightKit::Platforms::CarrierLogistics
end

shared_examples 'a DSDC platform carrier' do
  it_behaves_like 'a platform carrier', FreightKit::Platforms::DSDC
end

shared_examples 'a Next TMS platform carrier' do
  it_behaves_like 'a platform carrier', FreightKit::Platforms::NextTMS
end

shared_examples 'a The Great Information Factory platform carrier' do
  it_behaves_like 'a platform carrier', FreightKit::Platforms::TheGreatInformationFactory
end
