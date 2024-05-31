# frozen_string_literal: true

require 'yaml'
require 'erb'

module PgdumpScrambler
  module Utils
    module_function

    def load_yaml_with_erb(path)
      yaml_content = File.read(path)
      resolved = ERB.new(yaml_content).result
      YAML.safe_load(
        resolved,
        permitted_classes: [],
        permitted_symbols: [],
        aliases: true
      )
    end
  end
end
