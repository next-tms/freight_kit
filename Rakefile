desc 'Load FreightKit'
task(:environment) do
  require_relative 'lib/freight_kit'
end

Dir[File.expand_path('tasks/*.rake', __dir__)].each { |task| import(task) }
