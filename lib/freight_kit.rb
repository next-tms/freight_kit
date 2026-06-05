# frozen_string_literal: true

require 'active_model'
require 'active_support/all'
require 'active_utils'
require 'business_time'
require 'httparty'
require 'measured'
require 'mimemagic'
require 'nokogiri'
require 'open-uri'
require 'place_kit'
require 'savon'
require 'watir'
require 'yaml'
require 'zeitwerk'

module FreightKit
  VERSION = File.read(File.expand_path('../VERSION', __dir__)).strip.freeze

  class Inflector < Zeitwerk::Inflector
    def camelize(basename, abspath)
      if basename =~ /\Ahttp_(.*)/
        return "HTTP#{super(::Regexp.last_match(1), abspath)}"
      end

      super
    end
  end
end

loader = Zeitwerk::Loader.for_gem

loader.collapse("#{__dir__}/freight_kit/errors")
loader.collapse("#{__dir__}/freight_kit/models")

# Carriers, platforms, helpers, and api_clients define top-level constants
# under FreightKit:: (e.g. FreightKit::ABFS, FreightKit::Rateable) rather
# than nested under the directory name, so they're loaded manually via the
# explicit requires below.
loader.ignore("#{__dir__}/freight_kit/api_clients.rb")
loader.ignore("#{__dir__}/freight_kit/api_clients")
loader.ignore("#{__dir__}/freight_kit/carriers.rb")
loader.ignore("#{__dir__}/freight_kit/carriers")
loader.ignore("#{__dir__}/freight_kit/helpers.rb")
loader.ignore("#{__dir__}/freight_kit/helpers")
loader.ignore("#{__dir__}/freight_kit/platforms.rb")
loader.ignore("#{__dir__}/freight_kit/platforms")

loader.inflector = FreightKit::Inflector.new

loader.setup

require 'rmagick'

require 'freight_kit/api_clients'
require 'freight_kit/helpers'
require 'freight_kit/platforms'
require 'freight_kit/carriers'
