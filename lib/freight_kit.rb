# frozen_string_literal: true

require 'active_support/all'
require 'zeitwerk'

module FreightKit
  VERSION = File.read(File.expand_path('../../VERSION', __FILE__)).strip.freeze

  class Inflector < Zeitwerk::Inflector
    def camelize(basename, abspath)
      if basename =~ /\Ahttp_(.*)/
        return "HTTP#{super(::Regexp.last_match(1), abspath)}"
      end

      super
    end
  end
end

loader = Zeitwerk::Loader.for_gem

loader.inflector = FreightKit::Inflector.new

loader.setup
