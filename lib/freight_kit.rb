require 'active_model'
require 'active_support/all'
require 'active_utils'
require 'business_time'
require 'countries'
require 'httpx'
require 'measured'
require 'mimemagic'
require 'multi_xml'
require 'nokogiri'
require 'open-uri'
require 'place_kit'
require 'savon'
require 'street_address'
require 'watir'
require 'yaml'
require 'zeitwerk'

module FreightKit
  VERSION = File.read(File.expand_path('../VERSION', __dir__)).strip.freeze

  class Inflector < Zeitwerk::Inflector
    CARRIER_ACRONYMS = [
      'AAA',
      'AB',
      'ABF',
      'BA',
      'CDC',
      'CDO',
      'CMS',
      'CND',
      'CPL',
      'CSA',
      'CSX',
      'DAK',
      'DBR',
      'DHL',
      'DRT',
      'ERA',
      'EW',
      'GLS',
      'GPS',
      'GSA',
      'GSP',
      'GSV',
      'GTA',
      'HER',
      'HN',
      'JB',
      'JFJ',
      'JKB',
      'JLM',
      'JP',
      'KLC',
      'KM',
      'KMA',
      'KRC',
      'KTX',
      'LD',
      'LJ',
      'LKP',
      'LTL',
      'MC',
      'MS',
      'MVG',
      'NT',
      'NVK',
      'NY',
      'PG',
      'PGS',
      'PKI',
      'PWC',
      'RAC',
      'RE',
      'RIST',
      'RP',
      'RPM',
      'SB',
      'SNA',
      'SSI',
      'STG',
      'THK',
      'TILI',
      'TMA',
      'TMS',
      'TMT',
      'TSI',
      'UP',
      'UPS',
      'US',
      'USA',
      'USF',
      'VC',
      'VMG',
      'WDWB',
      'WLB',
      'XPO',
      'YRC'
    ].index_by(&:downcase).freeze

    def camelize(basename, abspath)
      if ['carriers', 'platforms'].include?(File.basename(File.dirname(abspath)))
        # Carriers and platforms are named after the business (e.g. nt_usa.rb => NTUSA, next_tms.rb => NextTMS)
        return basename.split('_').map { |word| CARRIER_ACRONYMS[word] || word.capitalize }.join
      end

      return "HTTP#{super(::Regexp.last_match(1), abspath)}" if basename =~ /\Ahttp_(.*)/

      super
    end
  end
end

loader = Zeitwerk::Loader.for_gem

loader.collapse("#{__dir__}/freight_kit/api_clients")
loader.collapse("#{__dir__}/freight_kit/errors")
loader.collapse("#{__dir__}/freight_kit/helpers")
loader.collapse("#{__dir__}/freight_kit/models")

loader.inflector = FreightKit::Inflector.new

loader.setup
