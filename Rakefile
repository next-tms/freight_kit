desc 'Load FreightKit'
task(:environment) { require_relative 'lib/freight_kit' }

Dir[File.expand_path('tasks/*.rake', __dir__)].each { |task| import(task) }
