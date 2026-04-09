# frozen_string_literal: true

version = File.read(File.expand_path('VERSION', __dir__)).strip.freeze

Gem::Specification.new do |spec|
  spec.name = 'freight_kit-next'
  spec.version = version

  spec.authors = 'Third Party Transportation Systems LLC'
  spec.email = 'hello@next-tms.com'

  spec.description = 'This library is a FreightKit plug-in that enables Next TMS partner carrier services'
  spec.homepage = 'https://github.com/next-tms/freight_kit-next'
  spec.summary = spec.description

  spec.files = Dir['lib/**/*'] +
               Dir['configuration/*/*.yml'] +
               Dir['[A-Z]*'] +
               Dir['test/**/*']
  spec.require_paths = ['lib']

  spec.add_dependency('freight_kit', '~> 0.1.13')
  spec.add_dependency('rmagick', '>= 4.2.5', '< 6.4.0')

  spec.add_development_dependency('faker', '~> 3.6.1')
  spec.add_development_dependency('rspec', '~> 3.13.0')
  spec.add_development_dependency('rubocop-next', '~> 1.0.6')
end
