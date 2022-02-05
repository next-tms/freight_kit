# frozen_string_literal: true

require 'active_model'
require 'active_support/all'
require 'active_utils'

require 'httparty'
require 'measured'
require 'mimemagic'
require 'nokogiri'
require 'open-uri'
require 'rmagick'
require 'savon'
require 'watir'
require 'yaml'

require 'interstellar/error'
require 'interstellar/errors'

require 'interstellar/model'
require 'interstellar/models'

require 'interstellar/carrier'
require 'interstellar/contact'
require 'interstellar/location'
require 'interstellar/package_item'
require 'interstellar/package'
require 'interstellar/packaging'
require 'interstellar/platform'
require 'interstellar/shipment_event'
require 'interstellar/shipment_packer'
require 'interstellar/tariff'
