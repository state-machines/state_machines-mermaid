# frozen_string_literal: true

require_relative 'character'

# Dragon with multiple parallel state machines
class Dragon < Character
  attr_accessor :rage, :treasure_hoard, :territory, :wingspan, :fire_breath_cooldown, :age, :last_meal_time, :injuries,
                :current_target, :dive_distance, :devastation_score

  def initialize
    super
    @rage = 0
    @treasure_hoard = 1000
    @territory = 100
    @wingspan = 50
    @fire_breath_cooldown = 0
  end

  # Mood state machine with states
  state_machine :mood, initial: :sleeping, namespace: 'dragon' do
    state :sleeping do
      def snoring?
        true
      end

      def alert_level
        :minimal
      end
    end

    # Sub-states would be separate state machines in state_machines gem
    state :light_sleep
    state :deep_sleep
    state :hibernating

    state :hunting do
      def alert_level
        :high
      end

      def speed_bonus
        1.5
      end
    end

    state :stalking
    state :pursuing
    state :feeding

    state :hoarding do
      def greed_multiplier
        2.0
      end

      def treasure_sense_range
        1000
      end
    end

    state :rampaging do
      def damage_multiplier
        3.0
      end

      def fear_aura_range
        500
      end
    end

    # Complex event transitions
    event :wake_up do
      transition sleeping: :hunting, if: :hungry?
      transition sleeping: :hoarding, if: :treasure_nearby?
      transition light_sleep: :hunting
      transition deep_sleep: :light_sleep
      transition hibernating: :deep_sleep, if: :winter_ended?
    end

    event :find_treasure do
      transition hunting: :hoarding
      transition hoarding: same # Keep hoarding more
      transition rampaging: :hoarding, if: -> { rage < 50 }
    end

    event :enrage do
      transition any - :rampaging => :rampaging, if: -> { rage > 75 }
    end

    event :exhaust do
      transition rampaging: :sleeping, if: -> { stamina <= 0 }
      transition %i[hunting hoarding] => :sleeping, if: :tired?
    end

    # Callbacks with conditions
    before_transition any => :rampaging do |dragon|
      dragon.rage = 100
      dragon.fire_breath_cooldown = 0
    end

    after_transition to: :hoarding, &:count_treasure

    around_transition from: :rampaging do |dragon, _transition, block|
      villages_before = dragon.nearby_villages.count
      block.call
      villages_after = dragon.nearby_villages.count
      dragon.devastation_score += (villages_before - villages_after)
    end
  end

  # Flight state machine
  state_machine :flight, initial: :grounded do
    state :grounded do
      def can_dodge?
        false
      end
    end

    state :hovering do
      def stability
        0.8
      end
    end

    state :soaring do
      def speed
        200
      end
    end

    state :diving do
      def attack_bonus
        5.0
      end
    end

    event :take_off do
      transition grounded: :hovering, if: -> { stamina > 50 && !wing_injured? }
    end

    event :ascend do
      transition hovering: :soaring, if: :weather_permits?
      transition diving: :soaring
    end

    event :dive_attack do
      transition %i[hovering soaring] => :diving, if: :target_spotted?
    end

    event :crash_land do
      transition %i[hovering soaring diving] => :grounded
    end

    after_transition on: :crash_land, to: :grounded do |dragon|
      dragon.take_damage(20)
    end

    event :land do
      transition %i[hovering soaring] => :grounded
      transition diving: :grounded, if: :dive_completed?
    end
  end

  # Age progression state machine
  state_machine :age_category, initial: :wyrmling do
    state :wyrmling
    state :young
    state :adult
    state :ancient
    state :great_wyrm

    event :age do
      transition wyrmling: :young, if: -> { age >= 50 }
      transition young: :adult, if: -> { age >= 200 }
      transition adult: :ancient, if: -> { age >= 800 }
      transition ancient: :great_wyrm, if: -> { age >= 1200 }
    end
  end

  # Dragon-specific methods
  def hungry?
    @last_meal_time && (Time.now - @last_meal_time) > 86_400
  end

  def treasure_nearby?
    sense_treasure_within(100)
  end

  def winter_ended?
    Time.now.month.between?(3, 10)
  end

  def tired?
    stamina < 30
  end

  def count_treasure
    @treasure_hoard = calculate_hoard_value
  end

  def wing_injured?
    @injuries&.include?(:wing)
  end

  def weather_permits?
    !stormy? && visibility > 100
  end

  def target_spotted?
    @current_target != nil
  end

  def dive_completed?
    @dive_distance && @dive_distance <= 0
  end

  def take_damage(amount)
    self.health -= amount
  end

  attr_reader :nearby_villages

  def sense_treasure_within(_range)
    false # Implement treasure detection
  end

  def calculate_hoard_value
    treasure_hoard * greed_multiplier
  end

  def stormy?
    false
  end

  def visibility
    1000
  end
end
