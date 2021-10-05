require 'test_helper'

class ExternalReturnLabelRequestTest < ActiveSupport::TestCase
  include Interstellar::Test::Fixtures

  setup do
    @external_request_label_req =
      ExternalReturnLabelRequest.from_hash(
        customer_name: "Test Customer",
        customer_address1: "122 Hudson St.",
        customer_city: "New York",
        customer_state: "NY",
        customer_zipcode: "10013",
        label_format: "No Instructions",
        label_definition: "4X6",
        service_type_code: "044",
        merchant_account_id: "12345",
        mid: "12345678",
        call_center_or_self_service: "Customer",
        address_override_notification: "true",
      )
    @email = "no-reply@example.com"
    @invalid_email = "not_a_valid_email"
    @anything = "Any string"
    @blank_values = ["", "    "]
  end

  test "#recipient_bcc raises on an invalid email" do
    assert_raises(USPSValidationError) do
      @external_request_label_req.recipient_bcc = @invalid_email
    end
  end

  test "#recipient_bcc assigns the email" do
    @external_request_label_req.recipient_bcc = @email
    assert_equal @email, @external_request_label_req.recipient_bcc
  end

  test "#recipient_email raises if invalid" do
    assert_raises(USPSValidationError) do
      @external_request_label_req.recipient_email = @invalid_email
    end
  end

  test "#recipient_email assigns the email" do
    @external_request_label_req.recipient_email = @email
    assert_equal @email, @external_request_label_req.recipient_email
  end

  test "#recipient_name accepts anything" do
    @external_request_label_req.recipient_name = @anything
    assert_equal @anything, @external_request_label_req.recipient_name
  end

  test "#sender_email raises if invalid" do
    assert_raises(USPSValidationError) do
      @external_request_label_req.sender_email = @invalid_email
    end
  end

  test "#sender_email assigns the email" do
    @external_request_label_req.sender_email = @email
    assert_equal @email, @external_request_label_req.sender_email
  end

  test "#sender_name assigns the value" do
    @external_request_label_req.sender_name = @anything
    assert_equal @anything, @external_request_label_req.sender_name
  end

  test "#sender_name raises if blank or nil" do
    @blank_values.each do |blank|
      assert_raises(USPSValidationError) do
        @external_request_label_req.sender_name = blank
      end
    end
  end

  test "#sender_name raises if nil" do
    assert_raises(USPSValidationError) do
      @external_request_label_req.sender_name = nil
    end
  end

  test "#image_type accepts a valid image type" do
    ExternalReturnLabelRequest::IMAGE_TYPE.each do |type|
      @external_request_label_req.image_type = type.downcase
      assert_equal type, @external_request_label_req.image_type
    end
  end

  test "#image_type raises on jpg" do
    assert_raises(USPSValidationError) do
      @external_request_label_req.image_type = "jpg"
    end
  end

  test "#call_center_or_self_service accepts the valid values defined" do
    ExternalReturnLabelRequest::CALL_CENTER_OR_SELF_SERVICE.each do |cc_or_cs|
      @external_request_label_req.call_center_or_self_service = cc_or_cs
      assert_equal cc_or_cs, @external_request_label_req.call_center_or_self_service
    end
  end

  test "#call_center_or_self_service raises on an invalid value" do
    assert_raises(USPSValidationError) do
      @external_request_label_req.call_center_or_self_service = "Invalid"
    end
  end

  test "#packaging_information accepts a value" do
    @external_request_label_req.packaging_information = @anything
    assert_equal @anything, @external_request_label_req.packaging_information
  end

  test "#packaging_information accepts blank values" do
    @blank_values.each do |blank|
      @external_request_label_req.packaging_information = blank
      assert_equal "", @external_request_label_req.packaging_information
    end
  end

  test "#packaging_information raises on a value too long" do
    assert_raises(USPSValidationError) do
      @external_request_label_req.packaging_information = "a" * 16
    end
  end

  test "#packaging_information2 accepts a value" do
    @external_request_label_req.packaging_information2 = @anything
    assert_equal @anything, @external_request_label_req.packaging_information2
  end

  test "#packaging_information2 accepts blank values" do
    @blank_values.each do |blank|
      @external_request_label_req.packaging_information2 = blank
      assert_equal "", @external_request_label_req.packaging_information2
    end
  end

  test "#packaging_information2 raises when a value is too long" do
    assert_raises(USPSValidationError) do
      @external_request_label_req.packaging_information2 = "a" * 16
    end
  end

  test "#customer_address2 accepts a value" do
    @external_request_label_req.customer_address2 = @anything
    assert_equal @anything, @external_request_label_req.customer_address2
  end

  test "#customer_address2 accepts blank values" do
    @blank_values.each do |blank|
      @external_request_label_req.customer_address2 = blank
      assert_nil @external_request_label_req.customer_address2
    end
  end

  test "#customer_address2 accepts nil" do
    @external_request_label_req.customer_address2 = nil
    assert_nil @external_request_label_req.customer_address2
  end

  test "#sanitize scrubs strings" do
    assert_equal "", @external_request_label_req.send(:sanitize,'   ')
    assert_equal 'some string', @external_request_label_req.send(:sanitize, 'some string   ')
    assert_nil @external_request_label_req.send(:sanitize, {})
    assert_nil @external_request_label_req.send(:sanitize, nil)
    assert_nil @external_request_label_req.send(:sanitize, nil)
    assert_nil @external_request_label_req.send(:sanitize, [])
    assert_equal ExternalReturnLabelRequest::CAP_STRING_LEN, @external_request_label_req.send(:sanitize, (1..100).to_a.join("_")).size
  end

  test "#to_bool coerces true values" do
    assert_equal true, @external_request_label_req.send(:to_bool, 'yes')
    assert_equal true, @external_request_label_req.send(:to_bool, 'true')
    assert_equal true, @external_request_label_req.send(:to_bool, true)
    assert_equal true, @external_request_label_req.send(:to_bool, '1')
  end

  test "#to_bool coerces false values" do
    assert_equal false, @external_request_label_req.send(:to_bool, '0')
    assert_equal false, @external_request_label_req.send(:to_bool, 'false')
    assert_equal false, @external_request_label_req.send(:to_bool, false)
    assert_equal false, @external_request_label_req.send(:to_bool, nil, false)
  end

  test "#validate_range" do
    assert_raises(USPSValidationError) do
      @external_request_label_req.send(:validate_range, '1', 5, 10, __method__)
    end
    assert_raises(USPSValidationError) do
      @external_request_label_req.send(:validate_range, '', 1, 10, __method__)
    end
    @external_request_label_req.send(:validate_range, '5 char', 3, 10, __method__)
    @external_request_label_req.send(:validate_range, '5 char', nil, 10, __method__)
  end

  test "#validate_string_length" do
    assert_raises(USPSValidationError) do
      @external_request_label_req.send(:validate_string_length, '14 char string', 13, __method__)
    end
    assert_raises(USPSValidationError) do
      @external_request_label_req.send(:validate_string_length, '14 char string', nil, __method__)
    end
    @external_request_label_req.send(:validate_string_length, '14 char string', 14, __method__)
  end

  test "#validate_set_inclusion" do
    assert_raises(USPSValidationError) do
      @external_request_label_req.send(:validate_set_inclusion, 'not_in_set', ['v1','v2','v3'], __method__)
    end
    assert_raises(USPSValidationError) do
      @external_request_label_req.send(:validate_set_inclusion, 'not_in_set', nil, __method__)
    end
    @external_request_label_req.send(:validate_set_inclusion, 'v1', ['v1','v2','v3'], __method__)
  end

  test "#validate_email" do
    assert_raises(USPSValidationError) do
      @external_request_label_req.send(:validate_email, @invalid_email, __method__)
    end
    assert_raises(USPSValidationError) do
      @external_request_label_req.send(:validate_email, "    ", __method__)
    end
    assert_equal @email, @external_request_label_req.send(:validate_email, @email, __method__)
    assert_equal @email, @external_request_label_req.send(:validate_email, "    #{@email}    ", __method__)
  end

  test "#initialize raises with no tag" do
    assert_raises(USPSMissingRequiredTagError) { ExternalReturnLabelRequest.new }
  end

  test "#initialize passes with valid values and that every key is necessary" do
    sample_hash = {
      :customer_name => "Test Customer",
      :customer_address1 => "122 Hudson St.",
      :customer_city => "New York",
      :customer_state => "NY",
      :customer_zipcode => "10013",
      :label_format => "No Instructions",
      :label_definition => "4X6",
      :service_type_code => "044",
      :merchant_account_id => "12345",
      :mid => "12345678",
      :call_center_or_self_service => "Customer",
      :address_override_notification => "true"
    }

    assert ExternalReturnLabelRequest.from_hash(sample_hash)

    sample_hash.keys.each do |k|
      assert_raises(USPSMissingRequiredTagError) do
        ExternalReturnLabelRequest.from_hash(sample_hash.reject {|k, v| k })
      end
    end
  end
end
