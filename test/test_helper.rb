# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/reporters'

require 'state_machines/test_helper'
require 'state_machines-mermaid'

StateMachines::Machine.ignore_method_conflicts = true

Dir[File.expand_path('support/models/**/*.rb', __dir__)].each { |file| require file }

module Minitest
  class Test
    include StateMachines::TestHelper
  end
end

Minitest::Reporters.use!(Minitest::Reporters::ProgressReporter.new)
