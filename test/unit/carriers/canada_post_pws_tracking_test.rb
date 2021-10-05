require 'test_helper'

class CanadaPostPwsTrackingTest < ActiveSupport::TestCase
  include Interstellar::Test::Fixtures

  def setup
    # 100 grams, 93 cm long, 10 cm diameter, cylinders have different volume calculations
    @pkg1 = Package.new(25, [93, 10], :cylinder => true)
    # 7.5 lbs, times 16 oz/lb., 15x10x4.5 inches, not grams, not centimetres
    @pkg2 = Package.new((7.5 * 16), [15, 10, 4.5], :units => :imperial)

    @home = Location.new(
      :name        => "John Smith",
      :company     => "test",
      :phone       => "613-555-1212",
      :address1    => "123 Elm St.",
      :city        => 'Ottawa',
      :province    => 'ON',
      :country     => 'CA',
      :postal_code => 'K1P1J1'
    )

    @dest = Location.new(
      :name     => "Frank White",
      :address1 => '999 Wiltshire Blvd',
      :city     => 'Beverly Hills',
      :state    => 'CA',
      :country  => 'US',
      :zip      => '90210'
    )

    @cp = CanadaPostPWS.new(platform_id: 123, api_key: '456', secret: '789')
  end

  def test_find_tracking_info_with_valid_pin
    pin = '1371134583769923'
    endpoint = @cp.endpoint + "vis/track/pin/%s/detail" % pin
    response = xml_fixture('canadapost_pws/tracking_details_en')
    @cp.expects(:ssl_get).with(endpoint, anything).returns(response)

    response = @cp.find_tracking_info(pin)
    assert response.is_a?(CPPWSTrackingResponse)
  end

  def test_find_tracking_info_with_15_digit_dnc
    dnc = "315052413796541"
    endpoint = @cp.endpoint + "vis/track/dnc/%s/detail" % dnc
    response = xml_fixture('canadapost_pws/dnc_tracking_details_en')
    @cp.expects(:ssl_get).with(endpoint, anything).returns(response)

    response = @cp.find_tracking_info(dnc)
    assert response.is_a?(CPPWSTrackingResponse)
  end

  def test_find_tracking_info_when_pin_doesnt_exist
    pin = '1371134583769924'
    response = xml_fixture('canadapost_pws/tracking_details_en_error')
    http_response = mock
    http_response.stubs(:code).returns('400')
    http_response.stubs(:body).returns(response)
    response_error = ActiveUtils::ResponseError.new(http_response)
    @cp.expects(:ssl_get).raises(response_error)

    exception = assert_raises Interstellar::ResponseError do
      @cp.find_tracking_info(pin)
    end

    assert_equal "No Pin History", exception.message
  end

  def test_find_tracking_info_with_invalid_pin_format
    pin = '123'
    @cp.expects(:ssl_get).never

    exception = assert_raises Interstellar::ResponseError do
      @cp.find_tracking_info(pin)
    end
    assert_equal "Invalid Pin Format", exception.message
  end

  # parse_tracking_response

  def test_parse_tracking_response
    @response = xml_fixture('canadapost_pws/tracking_details_en')
    @cp.expects(:ssl_get).returns(@response)

    response = @cp.find_tracking_info('1371134583769923', {})

    assert_equal CPPWSTrackingResponse, response.class
    assert_equal "Xpresspost", response.service_name
    assert_equal Date.parse("2011-02-01"), response.expected_date
    assert_equal "Customer addressing error found; attempting to correct", response.change_reason
    assert_equal "1371134583769923", response.tracking_number
    assert_equal 10, response.shipment_events.size

    assert_equal response.origin.city, "LACHINE"
    assert_equal response.origin.province, "QC"

    assert response.origin.is_a?(Location)
    assert response.destination.is_a?(Location)
    assert_equal "G1K4M7", response.destination.to_s
    assert_equal "0001371134", response.customer_number
    assert_equal true, response.delivered?
    assert_equal Time.parse('2011-02-03 16:59:59 UTC'), response.actual_delivery_time
  end

  def test_parse_tracking_response_no_expected_delivery_date
    @response = xml_fixture('canadapost_pws/tracking_details_no_expected_delivery_date')
    @cp.expects(:ssl_get).returns(@response)

    response = @cp.find_tracking_info('1371134583769923', {})

    assert_equal CPPWSTrackingResponse, response.class
    assert_equal "Expedited Parcels", response.service_name
    assert_nil response.expected_date
    assert_equal "8213295707205355", response.tracking_number
    assert_equal 1, response.shipment_events.size
    assert_equal response.origin.city, "MAPLE"
    assert_equal response.origin.province, "ON"
    assert response.origin.is_a?(Location)
    assert response.destination.is_a?(Location)
    assert_equal "J7Y0E4", response.destination.to_s
    assert_equal "0008213295", response.customer_number
    assert_equal false, response.delivered?
  end

  def test_parse_undelivered_tracking_response
    @response = xml_fixture('canadapost_pws/tracking_details_en_undelivered')
    @cp.expects(:ssl_get).returns(@response)
    response = @cp.find_tracking_info('1371134583769923', {})

    assert_equal false, response.delivered?
    assert_nil response.actual_delivery_time
  end

  def test_parse_tracking_response_shipment_events
    @response = xml_fixture('canadapost_pws/tracking_details_en')
    @cp.expects(:ssl_get).returns(@response)

    response = @cp.find_tracking_info('1371134583769923', {})
    events = response.shipment_events

    event = events.first
    assert_equal ShipmentEvent, event.class
    assert_equal "1496", event.name
    assert_equal "SAINTE-FOY, QC", event.location
    assert event.time.is_a?(Time)
    assert_equal "Item successfully delivered", event.message

    timestamps = events.map(&:time)
    ordered = timestamps.dup.sort.reverse # newest => oldest
    assert_equal ordered, timestamps
  end
end
