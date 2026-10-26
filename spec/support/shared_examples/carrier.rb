shared_examples 'a carrier' do
  uuid = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

  it { expect(FreightKit::Carriers.all).to(include(described_class)) }

  %i[
    acts_as_broker?
    bol_requires_tracking_number?
    consider_bol_and_pod_documents_same?
    create_pickup_implemented?
    find_rates_implemented?
    find_rates_with_declared_value?
    overlength_fees_require_tariff?
    pickup_number_is_tracking_number?
    rates_with_excessive_length_fees?
  ].each do |predicate|
    describe ".#{predicate}" do
      subject { described_class.public_send(predicate) }

      it { is_expected.to(be(true).or(be(false))) }
    end
  end

  {
    maximum_height: Measured::Length,
    maximum_weight: Measured::Weight,
    minimum_length_for_overlength_fees: Measured::Length
  }.each do |measure, type|
    describe ".#{measure}" do
      subject { described_class.public_send(measure) }

      it { is_expected.to(be_a(type).and(have_attributes(value: be_positive))) }
    end
  end

  describe '.check_mailing_addresses' do
    subject(:check_mailing_addresses) { described_class.check_mailing_addresses }

    it { is_expected.to(all(be_a(FreightKit::Address).and(have_attributes(country: be_a(FreightKit::Country))))) }
    it { is_expected.to(all(have_attributes(id: match(uuid)))) }
  end

  describe '.contacts' do
    subject(:contacts) { described_class.contacts }

    it { is_expected.to(all(be_a(FreightKit::Contact).and(have_attributes(name: nil)))) }
    it { is_expected.to(all(have_attributes(department: be_present))) }
    it { is_expected.to(all(have_attributes(id: match(uuid)))) }
  end

  describe '.headquarters' do
    subject(:headquarters) { described_class.headquarters }

    it { is_expected.to(be_nil.or(be_a(FreightKit::Address).and(have_attributes(country: be_a(FreightKit::Country))))) }
    it { is_expected.to(be_nil.or(have_attributes(id: match(uuid)))) }
  end

  describe '.id' do
    subject(:id) { described_class.id }

    it { is_expected.to(match(uuid)) }
  end

  describe '.legal_name' do
    subject(:legal_name) { described_class.legal_name }

    it { is_expected.to(be_nil.or(be_present)) }
  end

  describe '.mappable_accessorials' do
    subject(:mappable_accessorials) { described_class.mappable_accessorials }

    it { is_expected.to(be_a(Hash)) }
    it { expect(mappable_accessorials.keys).to(all(be_a(Symbol))) }
    it { expect(mappable_accessorials.keys & described_class.unserviceable_accessorials).to(be_empty) }
  end

  describe '.name' do
    subject(:name) { described_class.name }

    it { is_expected.to(be_present) }
  end

  describe '.required_credential_types' do
    subject(:required_credential_types) { described_class.required_credential_types }

    it { is_expected.to(all(be_a(Symbol))) }
  end

  describe '.requirements' do
    subject(:requirements) { described_class.requirements }

    it { expect(requirements - %i[credentials tariff]).to(be_empty) }
  end

  describe '.scac' do
    subject(:scac) { described_class.scac }

    it { is_expected.to(be_nil.or(match(/\A[A-Z]{4}\z/))) }
    it { is_expected.to(eq(scac&.upcase)) }
  end

  describe '.service_areas' do
    subject(:service_areas) { described_class.service_areas }

    it { is_expected.to(all(be_a(FreightKit::ServiceArea).and(have_attributes(country: be_a(FreightKit::Country))))) }
    it { is_expected.to(all(have_attributes(id: match(uuid)))) }
    it { is_expected.to(all(have_attributes(postal_codes: all(be_a(String))))) }

    it do
      expect(service_areas).to(all(satisfy { |area| area.regions.all? { |region| region.country == area.country } }))
    end

    it { expect(service_areas).to(all(satisfy { |area| (area.regions + area.postal_codes).any? })) }
  end

  describe '.services' do
    subject(:services) { described_class.services }

    it { is_expected.to(all(be_a(Symbol))) }
  end

  describe '.terminals' do
    subject(:terminals) { described_class.terminals }

    it { is_expected.to(all(be_a(FreightKit::Terminal).and(have_attributes(address: be_a(FreightKit::Address))))) }
    it { is_expected.to(all(have_attributes(address: have_attributes(id: match(uuid))))) }
    it { is_expected.to(all(have_attributes(id: match(uuid)))) }
  end

  describe '.tracking_url_templates' do
    subject(:tracking_url_templates) { described_class.tracking_url_templates }

    it { expect(tracking_url_templates.keys - FreightKit::Carrier::NUMBERS).to(be_empty) }
    it { expect(tracking_url_templates.values).to(all(be_a(String).and(include('%s')))) }
  end

  describe '.unquotable_accessorials' do
    subject(:unquotable_accessorials) { described_class.unquotable_accessorials }

    it { is_expected.to(all(be_a(Symbol))) }
    it { expect(unquotable_accessorials & described_class.unserviceable_accessorials).to(be_empty) }
  end

  describe '.unserviceable_accessorials' do
    subject(:unserviceable_accessorials) { described_class.unserviceable_accessorials }

    it { is_expected.to(all(be_a(Symbol))) }
  end

  describe '.us_dot_number' do
    subject(:us_dot_number) { described_class.us_dot_number }

    it { is_expected.to(be_nil.or(be_positive)) }
  end

  describe '.us_mc_number' do
    subject(:us_mc_number) { described_class.us_mc_number }

    it { is_expected.to(be_nil.or(be_positive)) }
  end

  describe '.valid_number_regexes' do
    subject(:valid_number_regexes) { described_class.valid_number_regexes }

    it { expect(valid_number_regexes.keys - FreightKit::Carrier::NUMBERS).to(be_empty) }
    it { expect(valid_number_regexes.values).to(all(be_a(Regexp))) }
  end

  describe '.website_url' do
    subject(:website_url) { described_class.website_url }

    it { is_expected.to(be_nil.or(match(%r{\Ahttps://[a-z0-9.-]+\z}))) }
  end
end

shared_examples 'a carrier without an API' do
  it_behaves_like 'a carrier'

  it { expect(described_class).not_to(be_const_defined(:API)) }

  describe '.create_pickup_implemented?' do
    subject(:create_pickup_implemented?) { described_class.create_pickup_implemented? }

    it { is_expected.to(be(false)) }
  end

  describe '.find_rates_implemented?' do
    subject(:find_rates_implemented?) { described_class.find_rates_implemented? }

    it { is_expected.to(be(false)) }
  end

  describe '.mappable_accessorials' do
    subject(:mappable_accessorials) { described_class.mappable_accessorials }

    it { is_expected.to(be_empty) }
  end

  describe '.required_credential_types' do
    subject(:required_credential_types) { described_class.required_credential_types }

    it { is_expected.to(be_empty) }
  end

  describe '.services' do
    subject(:services) { described_class.services }

    it { is_expected.to(be_empty) }
  end

  describe '.valid_number_regex' do
    subject(:valid_number_regex) { described_class.valid_number_regex(:tracking_number) }

    it { is_expected.to(be_nil) }
  end
end
