version = File.read(File.expand_path('VERSION', __dir__)).strip.freeze

Gem::Specification.new do |spec|
  spec.name = 'freight_kit'
  spec.version = version

  spec.authors = [
    'Third Party Transportation Systems LLC',
    'Brody Hoskins',
    'Sub Pop Records',
    'Shopify'
  ]
  spec.email = [
    'hello@next-tms.com',
    'brody@brody.digital',
    'webmaster@subpop.com',
    'integrations-team@shopify.com'
  ]

  spec.description = 'Freight carrier API and website abstraction library for transportation management systems (TMS)'
  spec.homepage = 'https://github.com/next-tms/freight_kit'
  spec.summary = spec.description

  spec.files = Dir['[A-Z]*'] +
               Dir['configuration/*/*.yml'] +
               Dir['lib/**/*'] +
               Dir['test/**/*']
  spec.require_paths = ['lib']

  spec.add_development_dependency('faker', '~> 3.8.0')
  spec.add_development_dependency('rake', '~> 13.4.2')
  spec.add_development_dependency('redcarpet', '~> 3.6.0') # for yard
  spec.add_development_dependency('rspec', '~> 3.12')
  spec.add_development_dependency('rubocop-next', '~> 1.0.9')
  spec.add_development_dependency('yard', '~> 0.9.28')

  spec.add_dependency('activemodel', '>= 7.1', '< 8.1.5')
  spec.add_dependency('activesupport', '>= 7.1', '< 8.1.5')
  spec.add_dependency('active_utils', '>= 3.3.1', '< 3.7.0')
  spec.add_dependency('benchmark', '~> 0.5.0')
  spec.add_dependency('brotli', '>= 0.9.2', '< 1') # CVE-2026-111497
  spec.add_dependency('business_time', '~> 0.13.0')
  spec.add_dependency('countries', '~> 8.1')
  spec.add_dependency('httpx', '>= 1.9.0', '< 2')
  spec.add_dependency('json', '< 4') # measured
  spec.add_dependency('measured', '>= 2.0', '< 3.2.3')
  spec.add_dependency('mimemagic', '~> 0.4.3')
  spec.add_dependency('multi_xml', '>= 0.9.1', '< 1')
  spec.add_dependency('nokogiri', '>= 1.6', '< 1.20')
  spec.add_dependency('place_kit', '~> 0.0.6')
  spec.add_dependency('savon', '>= 2.17', '< 2.18')
  spec.add_dependency('StreetAddress', '~> 2.0')
  spec.add_dependency('tzinfo-data', '~> 1.2023', '>= 1.2023.3')
  spec.add_dependency('watir', '>= 7.0', '< 7.4')
  spec.add_dependency('zeitwerk', '>= 2.6.0', '< 2.8.4')
  spec.add_dependency('zstd-ruby', '>= 2.0.10', '< 3') # bundles libzstd >= 1.5.4 (CVE-2022-4899)

  spec.required_ruby_version = '>= 3.3.0'
end
