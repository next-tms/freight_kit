require 'test_helper'

class CanadaPostPwsRegisterTest < ActiveSupport::TestCase
  include Interstellar::Test::Fixtures

  def setup
    @cp = CanadaPostPWS.new(platform_id: 123, api_key: '456', secret: '789')
  end

  def test_register_merchant
    endpoint = @cp.endpoint + "ot/token"
    response = xml_fixture('canadapost_pws/register_token_response')
    @cp.expects(:ssl_post).with(endpoint, anything, anything).returns(response)

    response = @cp.register_merchant
    assert response.is_a?(CPPWSRegisterResponse)
    assert_equal "34536456345353534535", response.token_id
  end

  def test_register_merchant_with_error
    endpoint = @cp.endpoint + "ot/token"
    response = xml_fixture('canadapost_pws/register_token_error')
    http_response = mock
    http_response.stubs(:code).returns('400')
    http_response.stubs(:body).returns(response)
    response_error = ActiveUtils::ResponseError.new(http_response)
    @cp.expects(:ssl_post).with(endpoint, anything, anything).raises(response_error)

    exception = assert_raises Interstellar::ResponseError do
      @cp.register_merchant
    end

    assert_equal "Platform not active", exception.message
  end

  def test_register_response_redirect_url
    endpoint = @cp.endpoint + "ot/token"
    response = xml_fixture('canadapost_pws/register_token_response')
    @cp.expects(:ssl_post).with(endpoint, anything, anything).returns(response)
    url = 'http://localhost:3000/cp-register/'
    customer_id = "12345"

    response = @cp.register_merchant
    assert_equal "http://www.canadapost.ca/cpotools/apps/drc/merchant?return-url=#{customer_id}&token-id=#{response.token_id}&platform-id=#{url}", response.redirect_url(url, customer_id)
  end

  def test_retrieve_merchant_details
    endpoint = @cp.endpoint + "ot/token/1234567890"
    response = xml_fixture('canadapost_pws/merchant_details_response')
    @cp.expects(:ssl_get).with(endpoint, anything).returns(response)

    response = @cp.retrieve_merchant_details(:token_id => '1234567890')
    assert response.is_a?(CPPWSMerchantDetailsResponse)
    assert_equal "1234567890", response.customer_number
    assert_equal "1234567890-", response.contract_number
    assert_equal "1234567890123456", response.username
    assert_equal "12343567890123456789012", response.password
    assert_equal false, response.has_default_credit_card
  end

  def test_retrieve_merchant_with_error
    endpoint = @cp.endpoint + "ot/token/1234567890"
    response = xml_fixture('canadapost_pws/merchant_details_error')
    http_response = mock
    http_response.stubs(:code).returns('400')
    http_response.stubs(:body).returns(response)
    response_error = ActiveUtils::ResponseError.new(http_response)
    @cp.expects(:ssl_get).with(endpoint, anything).raises(response_error)

    exception = assert_raises Interstellar::ResponseError do
      @cp.retrieve_merchant_details(:token_id => '1234567890')
    end

    assert_equal "Merchant Details Error", exception.message
  end
end
