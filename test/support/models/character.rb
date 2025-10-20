# frozen_string_literal: true

# Base character class with complex state machine
class Character
  attr_accessor :health, :mana, :stamina, :experience, :level, :gold, :inventory

  def initialize
    @health = 100
    @mana = 100
    @stamina = 100
    @experience = 0
    @level = 1
    @gold = 0
    @inventory = []
    super
  end

  state_machine :status, initial: :idle do
    # Basic states
    state :idle do
      def currently_resting?
        true
      end
    end

    state :combat do
      def in_danger?
        true
      end
    end

    state :casting do
      def actively_casting?
        true
      end
    end

    state :resting do
      def regenerating?
        true
      end
    end

    state :stunned do
      def incapacitated?
        true
      end
    end

    state :dead do
      def game_over?
        true
      end
    end

    # Complex transitions with conditions
    event :engage do
      transition idle: :combat, if: :can_fight?
      transition resting: :combat, if: :interrupt_rest?
      transition casting: :combat, unless: :spell_locked?
    end

    event :cast_spell do
      transition %i[idle combat] => :casting, if: :has_mana?
      transition casting: same, if: :channeling_spell?
    end

    event :rest do
      transition %i[idle combat] => :resting, unless: :in_danger?
      transition stunned: :resting, if: :recovered?
    end

    event :stun do
      transition %i[idle combat casting] => :stunned
    end

    event :recover do
      transition stunned: :idle, if: :stun_expired?
      transition resting: :idle, if: :fully_rested?
    end

    event :die do
      transition all - :dead => :dead
    end

    event :resurrect do
      transition dead: :idle, if: :can_resurrect?
    end

    # Complex callbacks
    before_transition on: :cast_spell do |char, transition|
      char.mana -= calculate_mana_cost(transition)
    end

    after_transition to: :resting, &:start_regeneration

    after_transition from: :casting, to: :idle, &:apply_spell_effects

    around_transition on: :die do |char, _transition, block|
      char.drop_items
      block.call
      char.notify_party
      char.create_tombstone
    end

    # Guards would go here if using ActiveModel/ActiveRecord
    # For plain Ruby objects, we handle validation in the condition methods
  end

  # Helper methods for conditions
  def can_fight?
    health.positive? && stamina > 10 && !incapacitated?
  end

  def has_mana?
    mana >= 10
  end

  def channeling_spell?
    @channeling_time&.positive?
  end

  def spell_locked?
    @spell_lock_time && @spell_lock_time > Time.now
  end

  def in_danger?
    false # Override in combat scenarios
  end

  def interrupt_rest?
    true
  end

  def recovered?
    @stun_duration && @stun_duration <= 0
  end

  def stun_expired?
    recovered?
  end

  def fully_rested?
    health == 100 && mana == 100
  end

  def can_resurrect?
    level > 10 || has_resurrection_item?
  end

  def has_resurrection_item?
    inventory.any? { |item| item.type == :resurrection }
  end

  def incapacitated?
    false
  end

  def calculate_mana_cost(_transition)
    10 # Base cost, can be overridden
  end

  def start_regeneration
    @regenerating = true
  end

  def apply_spell_effects
    # Apply any lingering spell effects
  end

  def drop_items
    @dropped_items = inventory.dup
    inventory.clear
  end

  def notify_party
    # Notify party members
  end

  def create_tombstone
    # Create memorial
  end
end
