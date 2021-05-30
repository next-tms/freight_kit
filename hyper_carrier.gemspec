# frozen_string_literal: true

lib = File.expand_path('../lib/', __FILE__)
$:.unshift(lib) unless $:.include?(lib)

require 'hyper_carrier/version'

Gem::Specification.new do |spec|
  spec.name = 'hyper_carrier'
  spec.license = 'MIT'
  spec.version = HyperCarrier::VERSION
  spec.date = '2021-04-02'

  spec.authors = [
    'Brody Hoskins',
    'Sub Pop Records',
    'Shopify'
  ]
  spec.email = [
    'brody@brody.digital',
    'webmaster@subpop.com',
    'integrations-team@shopify.com'
  ]

  spec.summary = 'Shipping API abstraction layer for package and freight carriers'
  spec.description = <<~DESC.gsub(/\n/, ' ').strip
    Hypercarrier is a shipping API abstraction layer for package and freight
    carriers. It's based on ReactiveFreight, ReactiveShipping and ActiveShipping.
  DESC
  spec.homepage = 'https://github.com/brodyhoskins/hyper_shipping'

  spec.files = Dir['lib/**/*']
  spec.files += Dir['[A-Z]*'] + Dir['test/**/*']
  spec.files.reject! { |fn| fn.include? 'CVS' }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'business_time', '~> 0.10.0'
  spec.add_development_dependency 'minitest-reporters', '~> 1.4.3'
  spec.add_development_dependency 'minitest', '~> 5.14.4'
  spec.add_development_dependency 'mocha', '~> 1.12.0'
  spec.add_development_dependency 'pry-byebug', '~> 3.9.0'
  spec.add_development_dependency 'pry', '~> 0.13.1'
  spec.add_development_dependency 'rake', '~> 13.0.3'
  spec.add_development_dependency 'timecop', '~> 0.9.4'
  spec.add_development_dependency 'vcr', '~> 6.0.0'
  spec.add_development_dependency 'webmock', '~> 3.13.0'

  spec.add_dependency 'active_utils', '~> 3.3.1'
  spec.add_dependency 'activesupport', '>= 4.2', '< 6.2'
  spec.add_dependency 'httparty', '~> 0.10'
  spec.add_dependency 'measured', '>= 2.0'
  spec.add_dependency 'nokogiri', '>= 1.6'
  spec.add_dependency 'rmagick', '>= 4.1', '< 4.3'
  spec.add_dependency 'savon', '>= 2.0', '< 2.13'
  spec.add_dependency 'watir', '>= 6.1', '< 6.20'
  spec.add_dependency 'webdrivers', '>= 4.0', '< 4.7'
end