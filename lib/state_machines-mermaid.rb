# frozen_string_literal: true

require 'state_machines'
require 'state_machines-diagram'
require 'state_machines/mermaid/version'
require 'state_machines/mermaid/renderer'

# Set the renderer to use mermaid
StateMachines::Machine.renderer = StateMachines::Mermaid::Renderer