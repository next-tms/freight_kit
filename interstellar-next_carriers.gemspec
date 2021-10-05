# frozen_string_literal: true

lib = File.expand_path('../lib/', __FILE__)
$:.unshift(lib) unless $:.include?(lib)

Gem::Specification.new do |spec|
  spec.name = 'interstellar-next_carriers'
  spec.version = '0.1.pre1'
  spec.date = '2021-10-04'

  spec.authors = [
    'Third Party Transportation Systems LLC'
  ]
  spec.email = [
    'hello@next-tms.com'
  ]

  spec.summary = 'This library is an Interstellar Carrier plug-in that enables Next TMS partner carrier services'
  spec.description = spec.summary
  spec.homepage = 'https://github.com/next-tms/interstellar-next_carriers'

  spec.files = Dir['lib/**/*']
  spec.files += Dir['[A-Z]*'] + Dir['test/**/*']
  spec.files.reject! { |fn| fn.include? 'CVS' }
  spec.require_paths = ['lib']

  spec.add_dependency 'interstellar', '0.0.pre1'
  spec.add_dependency 'interstellar-next_platforms', '0.0.pre1'
end
