require 'spec_helper'

describe FreightKit::Carriers do
  describe '.all' do
    subject(:carriers) { described_class.all }

    let(:ids) do
      carriers.flat_map do |carrier|
        addresses = [carrier.headquarters, *carrier.check_mailing_addresses, *carrier.terminals.map(&:address)].compact
        [carrier.id, *(addresses + carrier.contacts + carrier.service_areas + carrier.terminals).map(&:id)]
      end
    end

    it { expect(carriers.filter_map(&:scac)).to(eq(carriers.filter_map(&:scac).uniq)) }
    it { expect(ids).to(eq(ids.uniq)) }
  end

  describe '.find_by' do
    subject { described_class.find_by(id: '26a6a0c0-2e95-4835-ad73-4a3c8bb38cdd') }

    it { is_expected.to(eq(FreightKit::Carriers::Saia)) }
  end

  # Applications store these ids, so a released id never changes or disappears, and check mailing addresses keep
  # their order. Run `rake carriers:snapshot_ids` after adding data.
  YAML.load_file(File.expand_path('../fixtures/carrier_ids.yml', __dir__)).each do |id, released|
    describe "released carrier #{id}" do
      subject(:carrier) { described_class.find_by(id:) }

      let(:check_ids) { carrier.check_mailing_addresses.map(&:id) }
      let(:released_check_ids) { released['check_mailing_addresses'] }

      it { is_expected.to(be_present) }
      it { expect(check_ids.first(released_check_ids.size)).to(eq(released_check_ids)) }
      it { expect(released['contacts'] - carrier.contacts.map(&:id)).to(be_empty) }
      it { expect(carrier.headquarters&.id).to(eq(released['headquarters'])) }
      it { expect(released['service_areas'] - carrier.service_areas.map(&:id)).to(be_empty) }
      it { expect(released['terminals'] - carrier.terminals.map(&:id)).to(be_empty) }
    end
  end

  without_api = described_class.all.select do |carrier|
    carrier.superclass == FreightKit::Carrier && carrier.instance_methods(false).empty?
  end

  without_api.each do |carrier|
    describe carrier do
      it_behaves_like 'a carrier without an API'
    end
  end
end
