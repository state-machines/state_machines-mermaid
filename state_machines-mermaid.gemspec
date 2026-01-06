require_relative 'lib/state_machines/mermaid/version'

Gem::Specification.new do |spec|
  spec.name          = 'state_machines-mermaid'
  spec.version       = StateMachines::Mermaid::VERSION
  spec.authors       = ['Abdelkader Boudih']
  spec.email         = ['terminale@gmail.com']
  spec.summary       = %q(Mermaid renderer for state machines)
  spec.description   = %q(Mermaid diagrams for state machines. Adds Mermaid diagram generation to state machines using the diagram gem)
  spec.homepage      = 'https://github.com/state-machines/state_machines-mermaid'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.3.0'

  spec.files         = Dir['{lib}/**/*', 'LICENSE.txt', 'README.md']
  spec.test_files    = Dir['test/**/*']
  spec.require_paths = ['lib']

  spec.add_dependency 'state_machines', '>= 0.100.4'
  spec.add_dependency 'state_machines-diagram', '>= 0.1.0'
  spec.add_dependency 'mermaid'
  
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'minitest', '= 5.27.0'
  spec.add_development_dependency 'minitest-reporters'
end
