# frozen_string_literal: true

require 'spec_helper'

describe FreightKit::Carrier do
  subject(:carrier) { FreightKit::BTVP.allocate }

  def build_package(length:, width: 40, height: 40, quantity: 1)
    FreightKit::Package.new(
      480, # ounces
      { length:, width:, height: },
      :pallet,
      units: :imperial,
      quantity:,
    )
  end

  let(:non_overlength_package) { build_package(length: 48) } # under threshold
  let(:overlength_package) { build_package(length: 121) } # 121 in > 96 in threshold

  let(:covering_tariff) do
    FreightKit::Tariff.new(
      overlength_rules: [
                          {
                            min_length: Measured::Length.new(96, :inches),
                            max_length: nil,
                            fee_cents: 15_000
                          },
                        ],
    )
  end

  let(:empty_tariff) { FreightKit::Tariff.new(overlength_rules: []) }

  describe '#overlength_fee' do
    subject(:overlength_fee) { carrier.overlength_fee(tariff, package) }

    context 'with a covered overlength package' do
      let(:package) { overlength_package }
      let(:tariff) { covering_tariff }

      it { is_expected.to(eq(15_000)) }
    end

    context 'with a package under the overlength threshold' do
      let(:package) { non_overlength_package }
      let(:tariff) { covering_tariff }

      it { is_expected.to(eq(0)) }
    end

    context 'with multiple covered overlength packages' do
      let(:package) { build_package(length: 121, quantity: 3) }
      let(:tariff) { covering_tariff }

      it { is_expected.to(eq(45_000)) }
    end

    context 'with no tariff supplied' do
      let(:package) { overlength_package }
      let(:tariff) { nil }

      it { is_expected.to(eq(0)) }
    end
  end

  describe '#validate_packages' do
    subject(:validate_packages) { carrier.validate_packages(packages, tariff) }

    context 'with an overlength package and a covering tariff' do
      let(:packages) { [overlength_package] }
      let(:tariff) { covering_tariff }

      it { is_expected.to(be(true)) }
    end

    context 'with an overlength package and a nil tariff' do
      let(:packages) { [overlength_package] }
      let(:tariff) { nil }

      it { expect { validate_packages }.to(raise_error(FreightKit::UnserviceableError, /tariff must be defined/i)) }
    end

    context 'with an overlength package and a present-but-empty tariff' do
      let(:packages) { [overlength_package] }
      let(:tariff) { empty_tariff }

      it { expect { validate_packages }.to(raise_error(FreightKit::UnserviceableError, /tariff must be defined/i)) }
    end

    context 'with missing item dimensions' do
      let(:packages) { [build_package(length: 0, width: 0, height: 0)] }
      let(:tariff) { empty_tariff }

      it { expect { validate_packages }.to(raise_error(FreightKit::UnserviceableError, /dimensions are required/i)) }
    end

    context 'with only non-overlength packages and an empty tariff' do
      let(:packages) { [non_overlength_package] }
      let(:tariff) { empty_tariff }

      it { is_expected.to(be(true)) }
    end
  end
end
