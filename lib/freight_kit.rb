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
      # Carriers are named after their four-letter SCAC (e.g. abfs.rb => ABFS)
      if File.basename(File.dirname(abspath)) == 'carriers' && basename.match?(/\A[a-z]{4}\z/)
        return basename.upcase
      end

      if basename =~ /\Ahttp_(.*)/
        return "HTTP#{super(::Regexp.last_match(1), abspath)}"
      end

      super
    end
  end
end

loader = Zeitwerk::Loader.for_gem

loader.collapse("#{__dir__}/freight_kit/api_clients")
loader.collapse("#{__dir__}/freight_kit/carriers")
loader.collapse("#{__dir__}/freight_kit/errors")
loader.collapse("#{__dir__}/freight_kit/helpers")
loader.collapse("#{__dir__}/freight_kit/models")
loader.collapse("#{__dir__}/freight_kit/platforms")

loader.inflector = FreightKit::Inflector.new
loader.inflector.inflect('jfj_transportation' => 'JFJTransportation')

loader.setup
