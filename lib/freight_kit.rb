# frozen_string_literal: true

require 'active_model'
require 'active_support/all'
require 'active_utils'

require 'cgi'
require 'yaml'

require 'httparty'
require 'measured'
require 'mimemagic'
require 'nokogiri'
require 'open-uri'
require 'place_kit'
require 'savon'
require 'watir'

require 'zeitwerk'
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  'api' => 'API',
  'http' => 'HTTP',
  'http_error' => 'HTTPError',
  'json' => 'JSON',
  'xml' => 'XML',
)
loader.setup

module FreightKit
end
