# frozen_string_literal: true

require 'spec_helper'

describe FreightKit::AddressNormalizer do
  describe '.street_key' do
    it { expect(described_class.street_key('1415 Commerce PKWY N')).to(eq('1415 commerce pkwy n')) }
    it { expect(described_class.street_key('1415 Commerce Parkway North')).to(eq('1415 commerce pkwy n')) }
    it { expect(described_class.street_key('2700 Regent Blvd Ste 100')).to(eq('2700 regent blvd')) }
    it { expect(described_class.street_key('2700 Regent Blvd #100')).to(eq('2700 regent blvd')) }
    it { expect(described_class.street_key('3370 East La Palma Avenue')).to(eq('3370 e ln palma ave')) }
    it { expect(described_class.street_key('3370 East Lane')).to(eq('3370 e ln')) }
    it { expect(described_class.street_key('502 32nd St. S.W.')).to(eq('502 32nd st sw')) }
    it { expect(described_class.street_key('1835 US 9')).to(eq('1835 us 9')) }
    it { expect(described_class.street_key('Trade Center Drive')).to(be_nil) }
  end
end
