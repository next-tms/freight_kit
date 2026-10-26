require 'bundler/setup'
Bundler.setup

require 'faker'

require 'freight_kit'

Dir[File.join(__dir__, 'support/**/*.rb')].each { |file| require file }
