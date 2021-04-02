require 'pry'
require 'hyper_carrier'
require 'test_helper'

include HyperCarrier
include HyperCarrier::Test::Credentials
include HyperCarrier::Test::Fixtures

def create_carrier(klass, creds)
  options = credentials(creds).merge(:test => true)
  klass.new(options)
rescue NoCredentialsFound
  STDERR.puts "No credentials found for #{creds}"
  nil
end

def px(xml_s)
  puts Nokogiri.XML(xml_s)
end

def reload!
  # Supress a billion constant redefinition warnings
  warn_level = $VERBOSE
  $VERBOSE = nil

  files = $LOADED_FEATURES.select { |feat| feat =~ /\/hyper_carrier\// }
  files.each { |file| load file }

  $VERBOSE = warn_level
  files
end

# Prebuilt objects for most common carriers
@canpo    = create_carrier(CanadaPost,:canada_post)
@fedex    = create_carrier(FedEx,:fedex)
@shipwire = create_carrier(Shipwire,:shipwire)
@usps     = create_carrier(USPS,:usps)
# Tips: call reload! to reload all the hyper_carrier files, use fixtures from test_helpers for parameters
binding.pry
