require 'test_helper'

class CarriersTest < ActiveSupport::TestCase
  test ".find searches by string for a carrier and finds USPS" do
    assert_equal ReactiveShipping::USPS, ReactiveShipping::Carriers.find('usps')
    assert_equal ReactiveShipping::USPS, ReactiveShipping::Carriers.find('USPS')
  end

  test ".find searches by symbol for a carrier and finds USPS" do
    assert_equal ReactiveShipping::USPS, ReactiveShipping::Carriers.find(:usps)
  end

  test ".find raises with an unknown carrier" do
    assert_raises(NameError) { ReactiveShipping::Carriers.find(:polar_north) }
  end
end
