# frozen_string_literal: true

require_relative 'lib/state_machines/mermaid/version'

Gem::Specification.new do |spec|
  spec.name          = 'state_machines-mermaid'
  spec.version       = StateMachines::Mermaid::VERSION
  spec.authors       = ['Abdelkader Boudih']
  spec.email         = ['terminale@gmail.com']
  spec.summary       = 'Mermaid renderer for state machines'
  spec.description   = 'Mermaid diagrams for state machines. Adds Mermaid diagram generation to state machines ' \
                       'using the diagram gem'
  spec.homepage      = 'https://github.com/state-machines/state_machines-mermaid'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 4.0'

  spec.files         = Dir['{lib}/**/*', 'LICENSE.txt', 'README.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'diagram', '>= 0.4'
  spec.add_dependency 'mermaid', '>= 0.1'
  spec.add_dependency 'state_machines', '>= 0.300'
  spec.add_dependency 'state_machines-diagram', '>= 0.3.0'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'minitest', '~> 6.0'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency 'rake'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
