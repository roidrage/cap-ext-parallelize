require "#{File.dirname(__FILE__)}/capistrano/configuration/extensions/actions/invocation"
require "#{File.dirname(__FILE__)}/capistrano/configuration/extensions/connections"
require "#{File.dirname(__FILE__)}/capistrano/configuration/extensions/execution"

class Capistrano::Configuration
  include Capistrano::Configuration::Extensions::Actions::Invocation
  include Capistrano::Configuration::Extensions::Connections
  include Capistrano::Configuration::Extensions::Execution
end
