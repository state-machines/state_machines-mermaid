# frozen_string_literal: true

require 'state_machines'
require 'state_machines-diagram'
require 'state_machines/mermaid/version'
require 'state_machines/mermaid/renderer'

# Loading the gem changes no global state. Machine#draw (and State, Event
# and Branch#draw) use this renderer once it is chosen:
#
#   StateMachines::Machine.renderer = StateMachines::Mermaid::Renderer
#
# or draw with it directly: StateMachines::Mermaid::Renderer.draw_machine(machine)
