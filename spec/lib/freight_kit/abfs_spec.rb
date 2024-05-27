# frozen_string_literal: true

require 'spec_helper'

describe FreightKit::ABFS do
  let(:broker_credential) do
    FreightKit::Credential.new(
      type: :api_key,
      account: Faker::Number.number.to_s,
      api_key: Faker::Number.number(digits: 8).to_s,
    )
  end
  let(:tms_credential) do
    FreightKit::Credential.new(
      type: :api_key,
      api_key: Faker::Number.number(digits: 32).to_s,
    )
  end
  let(:credentials) { [broker_credential, tms_credential] }
  let(:customer_location) do
    FreightKit::Location.new(
      contact: FreightKit::Contact.new(
        company_name: Faker::Company.name,
        email: Faker::Internet.email,
      ),
      address1: Faker::Address.street_address,
      address2: [Faker::Address.street_address, nil].sample,
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
      2.times.map do
        FreightKit::Package.new(
          rand(1..9999) * 16,
          {
            length: rand(1..95),
            width: rand(1..95),
            height: rand(1..95)
          },
          :pallet,
          units: :imperial,
          quantity: 1,
          description: Faker::Lorem.words.join(' '),
        )
      end
    end
    let(:shipment) { FreightKit::Shipment.new(accessorials:, destination:, origin:, packages:) }

    let(:result) { carrier.send(:build_rate_request, shipment:) }

    let(:headers) { result[:headers] }
    let(:method) { result[:method] }
    let(:uri) { URI.parse(result[:url]) }

    let(:params) { Rack::Utils.parse_nested_query(uri.query) }

    it { expect(params.keys).not_to(include('LADType')) }
    it { expect(params['Acc_PALLET']).to(eq('Y')) }
    it { expect(params['Acc_SL']).to(eq('Y')) }
    it { expect(params['Acc_SS']).to(eq('Y')) }
    it { expect(params['APP_ID']).to(eq(tms_credential.api_key)) }
    it { expect(params['Class1']).to(eq(shipment.packages[0].freight_class.to_s)) }
    it { expect(params['ConsCity']).to(eq(destination.city)) }
    it { expect(params['ConsCountry']).to(eq(destination.country.code(:alpha2).value)) }
    it { expect(params['ConsState']).to(eq(destination.province)) }
    it { expect(params['ConsZip']).to(eq(destination.postal_code)) }
    it { expect(params['Cube']).to(be_present) }
    it { expect(params['FrtHght1']).to(eq(shipment.packages[0].inches(:height).to_s)) }
    it { expect(params['FrtLng1']).to(eq(shipment.packages[0].inches(:length).to_s)) }
    it { expect(params['FrtLng2']).to(eq(shipment.packages[1].inches(:length).to_s)) }
    it { expect(params['FrtLWHType']).to(eq('IN')) }
    it { expect(params['FrtWdth1']).to(eq(shipment.packages[0].inches(:width).to_s)) }
    it { expect(params['FrtWdth2']).to(eq(shipment.packages[1].inches(:width).to_s)) }
    it { expect(params['ID']).to(eq(broker_credential.api_key)) }
    it { expect(params['ODLongestSide']).to(be_present) }
    it { expect(params['ShipCity']).to(eq(origin.city)) }
    it { expect(params['ShipCountry']).to(eq(origin.country.code(:alpha2).value)) }
    it { expect(params['ShipDay']).to(be_present) }
    it { expect(params['ShipMonth']).to(be_present) }
    it { expect(params['ShipState']).to(eq(origin.province)) }
    it { expect(params['ShipYear']).to(be_present) }
    it { expect(params['ShipZip']).to(eq(origin.postal_code)) }
    it { expect(params['TPBAddr']).to(eq([customer_location.address1, customer_location.address2].compact.join(', '))) }
    it { expect(params['TPBAff']).to(eq('Y')) }
    it { expect(params['TPBCity']).to(eq(customer_location.city)) }
    it { expect(params['TPBCountry']).to(eq(customer_location.country.code(:alpha2).value)) }
    it { expect(params['TPBPay']).to(eq('Y')) }
    it { expect(params['TPBState']).to(eq(customer_location.province)) }
    it { expect(params['TPBZip']).to(eq(customer_location.postal_code)) }
    it { expect(params['UnitNo1']).to(eq(shipment.packages[0].quantity.to_s)) }
    it { expect(params['UnitNo2']).to(eq(shipment.packages[1].quantity.to_s)) }
    it { expect(params['UnitType1']).to(eq('PLT')) }
    it { expect(params['UnitType2']).to(eq('PLT')) }
    it { expect(params['Wgt1']).to(eq(shipment.packages[0].pounds(:total).to_s)) }
    it { expect(params['Wgt2']).to(eq(shipment.packages[1].pounds(:total).to_s)) }

    %i[church_delivery inside_delivery liftgate_delivery residential_delivery restaurant_delivery].each do |accessorial|
      context "when shipment.accessorials.include?(:#{accessorial})" do
        let(:accessorials) { [accessorial] }

        it { expect(params.keys).not_to(include('Acc_CUL')) }
      end
    end

    %i[church_pickup inside_pickup liftgate_pickup residential_pickup restaurant_pickup].each do |accessorial|
      context "when shipment.accessorials.include?(:#{accessorial})" do
        let(:accessorials) { [accessorial] }

        it { expect(params.keys).not_to(include('Acc_SL')) }
      end
    end

    %i[
church_delivery
military_site_delivery
school_delivery
storage_facility_delivery
university_delivery
].each do |accessorial|
      context "when shipment.accessorials.include?(:#{accessorial})" do
        let(:accessorials) { [accessorial] }

        it { expect(params['Acc_LAD']).to(eq('Y')) }
        it { expect(params['LADType']).to(be_present) }
      end
    end

    context 'when shipment.accessorials.include?(:liftgate_delivery)' do
      let(:accessorials) { %i[liftgate_delivery] }

      it { expect(params['Acc_GRD_DEL']).to(eq('Y')) }
    end

    context 'when not shipment.packages.map(&:packaging).all?(&:pallet?)' do
      let(:packages) do
        [
          FreightKit::Package.new(
            rand(1..9999) * 16,
            {
              length: rand(96..199),
              width: rand(1..199),
              height: rand(1..199)
            },
            :box,
            units: :imperial,
            quantity: 1,
            description: Faker::Lorem.words.join(' '),
          ),
        ]
      end

      it { expect(params.keys).not_to(include('Acc_PALLET')) }
      it { expect(params['UnitType1']).to(eq('BX')) }
    end

    context 'when longest_dimension_in >= 96' do
      let(:packages) do
        rand(1..9).times.map do
          FreightKit::Package.new(
            rand(1..9999) * 16,
            {
              length: rand(96..335),
              width: rand(1..100),
              height: rand(1..50)
            },
            %i[box pallet].sample,
            units: :imperial,
            quantity: 1,
            description: Faker::Lorem.words.join(' '),
          )
        end
      end

      it { expect(params['Acc_OD']).to(eq('Y')) }
    end

    context 'when longest_dimension_in >= 336' do
      let(:packages) do
        rand(1..9).times.map do
          FreightKit::Package.new(
            rand(1..9999) * 16,
            {
              length: rand(336..9_999),
              width: rand(1..100),
              height: rand(1..50)
            },
            %i[box pallet].sample,
            units: :imperial,
            quantity: 1,
            description: Faker::Lorem.words.join(' '),
          )
        end
      end

      it { expect(params['Acc_CAP']).to(eq('Y')) }
      it { expect(params['Acc_OD']).to(eq('Y')) }
    end
  end
end
