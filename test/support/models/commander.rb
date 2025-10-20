# frozen_string_literal: true

require_relative 'character'

# Commander class for regiment
class Commander < Character
  attr_accessor :leadership, :tactics, :inspiring

  def initialize
    super
    @leadership = 75
    @tactics = 80
    @inspiring = true
  end

  def alive?
    health.positive?
  end

  def with_regiment?
    !status?(:absent)
  end
end
