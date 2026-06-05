# frozen_string_literal: true

require 'spec_helper'

describe FreightKit::SEFL do
  let(:credentials) do
    FreightKit::Credential.new(
      type: :api,
      account: Faker::Number.number(digits: 9).to_s,
      username: Faker::Internet.username.upcase,
      password: Faker::Internet.password,
    )
  end
  let(:customer_location) do
    FreightKit::Location.new(
      contact: FreightKit::Contact.new(
        company_name: Faker::Company.name,
        email: Faker::Internet.email,
      ),
      address1: Faker::Address.street_address,
      city: Faker::Address.city,
      postal_code: Faker::Address.postcode,
      province: Faker::Address.state_abbr,
      country: ActiveUtils::Country.find('US'),
    )
  end

  let(:carrier) { described_class.new(credentials, customer_location:) }

  describe '#build_rate_request' do
    let(:accessorials) { [] }
    let(:destination) do
      FreightKit::Location.new(
        address1: Faker::Address.street_address,
        city: Faker::Address.city,
        postal_code: Faker::Address.postcode,
        province: Faker::Address.state_abbr,
        country: ActiveUtils::Country.find('US'),
      )
    end
    let(:origin) do
      FreightKit::Location.new(
        address1: Faker::Address.street_address,
        city: Faker::Address.city,
        postal_code: Faker::Address.postcode,
        province: Faker::Address.state_abbr,
        country: ActiveUtils::Country.find('US'),
      )
    end
    let(:packages) do
      rand(1..9).times.map do
        FreightKit::Package.new(
          rand(1..9999) * 16,
          {
            length: rand(1..95),
            width: rand(1..95),
            height: rand(1..95)
          },
          %i[box pallet].sample,
          units: :imperial,
          quantity: 1,
          description: Faker::Lorem.words.join(' '),
        )
      end
    end
    let(:shipment) { FreightKit::Shipment.new(accessorials:, destination:, origin:, packages:) }

    let(:result) { carrier.send(:build_rate_request, shipment:) }
    let(:body) { URI.decode_www_form(result[:body]).to_h }

    it { expect(body['allowSpot']).to(eq('N')) }
    it { expect(body['CustomerAccount']).to(eq(credentials.account)) }
    it { expect(body['CustomerCity']).to(eq(customer_location.city)) }
    it { expect(body['CustomerName']).to(eq(customer_location.contact.company_name)) }
    it { expect(body['CustomerState']).to(eq(customer_location.province)) }
    it { expect(body['CustomerStreet']).to(eq(customer_location.address1)) }
    it { expect(body['CustomerZip']).to(eq(customer_location.postal_code)) }
    it { expect(body['Description']).to(eq(shipment.packages.map(&:description).join(', '))) }
    it { expect(body['DestCountry']).to(eq('U')) }
    it { expect(body['DestinationCity']).to(eq(destination.city)) }
    it { expect(body['DestinationState']).to(eq(destination.province)) }
    it { expect(body['DestinationZip']).to(eq(destination.postal_code)) }
    it { expect(body['DimsOption']).to(eq('I')) }
    it { expect(body['EmailAddress']).to(eq(customer_location.contact.email)) }
    it { expect(body['Option']).to(eq('T')) }
    it { expect(body['OrigCountry']).to(eq('U')) }
    it { expect(body['OriginCity']).to(eq(shipment.origin.city)) }
    it { expect(body['OriginState']).to(eq(shipment.origin.province)) }
    it { expect(body['OriginZip']).to(eq(shipment.origin.postal_code)) }
    it { expect(body['PickupDay']).to(eq(Date.current.strftime('%_d'))) }
    it { expect(body['PickupMonth']).to(eq(Date.current.strftime('%_m'))) }
    it { expect(body['PickupYear']).to(eq(Date.current.strftime('%Y'))) }
    it { expect(body['rateXML']).to(eq('Y')) }
    it { expect(body['returnX']).to(eq('Y')) }
    it { expect(body['Terms']).to(eq('P')) }

    it { expect(body).not_to(have_key('accessorial')) }

    context 'when longest_dimension >= 96' do
      let(:packages) do
        rand(1..9).times.map do
          FreightKit::Package.new(
            rand(1..9999) * 16,
            {
              length: rand(96..199),
              width: rand(1..199),
              height: rand(1..199)
            },
            %i[box pallet].sample,
            units: :imperial,
            quantity: 1,
            description: Faker::Lorem.words.join(' '),
          )
        end
      end

      it { expect(body['accessorial']).to(eq('on')) }
      it { expect(body['chkOD']).to(eq('on')) }
    end

    context 'when longest_dimension >= 120' do
      let(:packages) do
        rand(1..9).times.map do
          FreightKit::Package.new(
            rand(1..9999) * 16,
            {
              length: rand(120..199),
              width: rand(120..199),
              height: rand(120..199)
            },
            %i[box pallet].sample,
            units: :imperial,
            quantity: 1,
            description: Faker::Lorem.words.join(' '),
          )
        end
      end

      it { expect(body['accessorial']).to(eq('on')) }
      it { expect(body['allowSpot']).to(eq('Y')) }
      it { expect(body['chkOD']).to(eq('on')) }
    end

    context 'when shipment.accessorials.any?' do
      let(:accessorial) { carrier.conf.dig(:accessorials, :mappable).keys.sample }
      let(:accessorials) { [accessorial] }

      it { expect(body['accessorial']).to(eq('on')) }
      it { expect(body[carrier.conf.dig(:accessorials, :mappable, accessorial)]).to(eq('on')) }
    end
  end
end
