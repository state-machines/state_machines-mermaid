# frozen_string_literal: true

# Phoenix whose transitions carry their own callbacks (transition ...,
# before:/around:/after:) next to the flame's machine callbacks. Every
# callback writes to #log, so a test can fire an event and read the order
# the core ran them in.
class Phoenix
  attr_accessor :flame, :log, :ritual, :feathers

  def initialize
    @log = []
    @ritual = true
    @feathers = 3
    super
  end

  state_machine :flame, initial: :ember do
    state :ash

    # The machine's callbacks, around every transition
    before_transition :stoke
    around_transition :channel
    before_transition :chant, if: :ritual?
    after_transition :scatter_sparks
    after_transition on: :rekindle, do: :sing

    # Branch callbacks, in the order written: before, around, after
    event :ignite do
      transition ember: :blaze, before: :gather_heat, around: :shield, after: :roar
    end

    # Several branches, each with its own callbacks: from ash the first
    # whose guard passes is taken
    event :rekindle do
      transition ash: :ember, if: :feathers_left?, after: %i[hatch preen]
      transition ash: :blaze, before: :flare, after: :erupt
      transition blaze: same, around: :circle
    end

    # A state context transition with callbacks, written around first
    state :blaze do
      transition to: :ash, on: :burn_out, around: :smolder, before: :dim, after: :crumble
    end
  end

  def ritual? = ritual

  def feathers_left? = feathers.positive?

  %i[stoke chant scatter_sparks sing gather_heat roar hatch preen flare erupt dim crumble].each do |name|
    define_method(name) { log << name.to_s }
  end

  %i[channel shield circle smolder].each do |name|
    define_method(name) do |_transition, &block|
      log << "#{name} enter"
      block.call
      log << "#{name} exit"
    end
  end
end
