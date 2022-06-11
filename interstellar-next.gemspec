# frozen_string_literal: true

lib = File.expand_path('../lib/', __FILE__)
$:.unshift(lib) unless $:.include?(lib)

Gem::Specification.new do |spec|
  spec.name = 'interstellar-next'
  spec.version = '0.1.pre24'
  spec.date = '2022-06-11'

  spec.authors = [
    'Third Party Transportation Systems LLC'
  ]
  spec.email = [
    'hello@next-tms.com'
  ]

  spec.summary = 'This library is an Interstellar plug-in that enables Next TMS partner carrier services'
  spec.description = spec.summary
  spec.homepage = 'https://github.com/next-tms/interstellar-next'

  spec.files = Dir['lib/**/*']
  spec.files += Dir['configuration/*/*.yml']
  spec.files += Dir['[A-Z]*'] + Dir['test/**/*']
  spec.files.reject! { |fn| fn.include? 'CVS' }
  spec.require_paths = ['lib']

  spec.add_dependency 'interstellar', '0.1.pre24'
  spec.add_dependency 'rmagick', '~> 4.2.5'
end
