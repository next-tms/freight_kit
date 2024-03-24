# frozen_string_literal: true

require_relative 'lib/freight_kit'

Gem::Specification.new do |spec|
  spec.name = 'freight_kit'
  spec.version = FreightKit::VERSION
  spec.authors = ['Third Party Transportation Systems LLC']
  spec.email = ['hello@next-tms.com']

  spec.description = 'Freight carrier API and website abstraction library for transportation management systems (TMS)'
  spec.summary = spec.description
  spec.homepage = 'https://github.com/next-tms/freight_kit'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = 'https://github.com/next-tms/freight_kit/blob/main/CHANGELOG.md'

  spec.files = Dir.chdir(__dir__) do
    %x(git ls-files -z).split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?('bin/', 'test/', 'spec/', 'features/', '.git', '.github', 'appveyor', 'Gemfile')
    end
  end
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency('rake', '~> 13.0')
  spec.add_development_dependency('rspec', '~> 3.0')
  spec.add_development_dependency('rubocop', '~> 1.21')
  spec.add_development_dependency('rubocop-next', '~> 1.0.3')

  spec.add_dependency('activesupport', '>= 4.2', '< 7.1.4')
  spec.add_dependency('zeitwerk', '>= 2.6.0', '< 2.6.13')
end
