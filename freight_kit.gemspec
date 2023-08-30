# frozen_string_literal: true

version = File.read(File.expand_path('VERSION', __dir__)).strip.freeze

Gem::Specification.new do |spec|
  spec.name = 'freight_kit'
  spec.version = version

  spec.authors = [
                   'Third Party Transportation Systems LLC',
                   'Brody Hoskins',
                   'Sub Pop Records',
                   'Shopify',
                 ]
  spec.email = [
                 'hello@next-tms.com',
                 'brody@brody.digital',
                 'webmaster@subpop.com',
                 'integrations-team@shopify.com',
               ]

  spec.description = 'Freight carrier API and website abstraction library for transportation management systems (TMS)'
  spec.homepage = 'https://github.com/next-tms/freight_kit'
  spec.summary = spec.description

  spec.files = Dir['lib/**/*'] +
               Dir['[A-Z]*'] +
               Dir['test/**/*']
  spec.require_paths = ['lib']

  spec.add_development_dependency('business_time', '~> 0.11.0')
  spec.add_development_dependency('minitest', '~> 5.15.0')
  spec.add_development_dependency('minitest-reporters', '~> 1.5.0')
  spec.add_development_dependency('mocha', '~> 1.13.0')
  spec.add_development_dependency('pry', '~> 0.13.1')
  spec.add_development_dependency('pry-byebug', '~> 3.9.0')
  spec.add_development_dependency('rake', '~> 13.0.3')
  spec.add_development_dependency('rubocop-next', '~> 1.0.3')
  spec.add_development_dependency('timecop', '~> 0.9.4')
  spec.add_development_dependency('vcr', '~> 6.1.0')
  spec.add_development_dependency('webmock', '~> 3.19.1')

  spec.add_development_dependency('redcarpet', '~> 3.5.1') # for yard
  spec.add_development_dependency('yard', '~> 0.9.28')

  spec.add_dependency('activemodel', '>= 4.2', '< 7.0.8')
  spec.add_dependency('activesupport', '>= 4.2', '< 7.0.8')
  spec.add_dependency('active_utils', '~> 3.3.1')
  spec.add_dependency('httparty', '~> 0.10')
  spec.add_dependency('measured', '>= 2.0', '< 2.8.3')
  spec.add_dependency('mimemagic', '~> 0.4.3')
  spec.add_dependency('nokogiri', '>= 1.6', '< 1.14')
  spec.add_dependency('place_kit', '~> 0.0.1')
  spec.add_dependency('savon', '>= 2.0', '< 2.13')
  spec.add_dependency('watir', '>= 7.0', '< 7.2')

  spec.required_ruby_version = '>= 3.2.0'
end
