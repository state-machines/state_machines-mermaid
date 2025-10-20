# frozen_string_literal: true

require_relative 'character'

# Troll with regeneration mechanics
class Troll < Character
  attr_accessor :regeneration_rate, :rage_level, :last_damage_type, :berserker_stacks, :last_fire_damage_time,
                :recovery_started, :health_changes, :enemies_nearby

  def initialize
    super
    @regeneration_rate = 5
    @rage_level = 0
    @berserker_stacks = 0
  end

  state_machine :regeneration, initial: :normal do
    state :normal do
      def regen_multiplier
        1.0
      end
    end

    state :accelerated do
      def regen_multiplier
        2.0
      end
    end

    state :berserk do
      def regen_multiplier
        3.0
      end

      def damage_taken_reduction
        0.5
      end
    end

    state :suppressed do
      def regen_multiplier
        0
      end
    end

    state :dormant do
      def regen_multiplier
        0.1
      end

      def appears_dead?
        true
      end
    end

    event :enrage do
      transition normal: :accelerated, if: -> { health < 75 }
      transition accelerated: :berserk, if: -> { rage_level > 75 && health < 50 }
    end

    event :take_fire_damage do
      transition %i[normal accelerated berserk] => :suppressed
    end

    event :take_acid_damage do
      transition %i[normal accelerated] => :suppressed
      transition berserk: :accelerated # Berserk provides some resistance
    end

    event :cool_down do
      transition suppressed: :normal, if: -> { time_since_fire_damage > 60 }
      transition %i[accelerated berserk] => :normal, unless: -> { health < 50 }
    end

    event :play_dead do
      transition %i[normal suppressed] => :dormant, if: -> { health < 10 }
    end

    event :rise_again do
      transition dormant: :normal, if: -> { health > 25 }
      transition dormant: :berserk, if: -> { rage_level > 90 }
    end

    after_transition any => :berserk do |troll|
      troll.regeneration_rate = 20
      troll.berserker_stacks = 5
    end

    after_transition any => :suppressed do |troll|
      troll.regeneration_rate = 0
    end

    after_transition to: :dormant do |troll|
      troll.regeneration_rate = 1
      troll.begin_slow_recovery
    end

    around_transition any => any do |troll, _transition, block|
      health_before = troll.health
      block.call
      health_after = troll.health
      troll.track_health_change(health_before - health_after)
    end
  end

  # Combat stance
  state_machine :combat_stance, initial: :defensive do
    state :defensive do
      def armor_bonus
        5
      end
    end

    state :aggressive do
      def attack_bonus
        3
      end
    end

    state :reckless do
      def attack_bonus
        6
      end

      def armor_penalty
        3
      end
    end

    event :change_stance do
      transition defensive: :aggressive, if: :confident?
      transition aggressive: :reckless, if: :bloodthirsty?
      transition %i[aggressive reckless] => :defensive, if: :threatened?
    end
  end

  def time_since_fire_damage
    return Float::INFINITY unless @last_fire_damage_time

    Time.now - @last_fire_damage_time
  end

  def begin_slow_recovery
    @recovery_started = Time.now
  end

  def track_health_change(amount)
    @health_changes ||= []
    @health_changes << { amount: amount, time: Time.now }
  end

  def confident?
    health > 75 && berserker_stacks.positive?
  end

  def bloodthirsty?
    rage_level > 80 && health > 50
  end

  def threatened?
    health < 30 || surrounded?
  end

  def surrounded?
    @enemies_nearby && @enemies_nearby.count > 3
  end
end
