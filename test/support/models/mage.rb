# frozen_string_literal: true

require_relative 'character'

# Mage with spell casting and specialization states
class Mage < Character
  attr_accessor :spell_power, :focus, :school_of_magic, :mana_pool, :spell_book, :affinities, :masteries, :traits,
                :trials_completed, :current_target, :channel_start_time, :cooldown_end_time

  def initialize
    super
    @spell_power = 50
    @focus = 100
    @mana_pool = 200
    @spell_book = []
    @known_spells = {}
  end

  # Mental state for concentration
  state_machine :concentration, initial: :focused do
    state :focused do
      def spell_critical_chance
        0.2
      end
    end

    state :distracted do
      def spell_failure_chance
        0.3
      end
    end

    state :deep_meditation do
      def mana_regeneration_rate
        5.0
      end

      def immune_to_interruption?
        true
      end
    end

    state :interrupted do
      def can_cast?
        false
      end
    end

    event :meditate do
      transition focused: :deep_meditation, if: -> { mana < 50 && safe_to_meditate? }
      transition distracted: :focused, if: :regain_composure?
    end

    event :disturb do
      transition %i[focused deep_meditation] => :distracted, unless: :iron_will?
    end

    event :break_concentration do
      transition any - :interrupted => :interrupted
    end

    event :refocus do
      transition %i[distracted interrupted] => :focused, if: :concentration_check?
    end

    after_transition to: :deep_meditation, &:begin_mana_regeneration
  end

  # Spell school specialization with complex hierarchy
  state_machine :spell_school, initial: :apprentice do
    # Apprentice level
    state :apprentice

    # Fire magic tree
    state :fire do
      def elemental_affinity
        :fire
      end
    end
    state :ember
    state :flame
    state :inferno

    # Ice magic tree
    state :ice do
      def elemental_affinity
        :ice
      end
    end
    state :frost
    state :freeze
    state :blizzard

    # Arcane magic tree
    state :arcane do
      def elemental_affinity
        :arcane
      end
    end
    state :missile
    state :explosion
    state :singularity

    # Master of multiple schools
    state :archmage do
      def can_dual_cast?
        true
      end
    end

    # Fire progression
    event :study_fire do
      transition apprentice: :ember, if: :has_fire_affinity?
      transition ember: :flame, if: -> { spell_power > 75 && knows_spell?(:fireball) }
      transition flame: :inferno, if: -> { spell_power > 150 && fire_mastery_complete? }
    end

    # Ice progression
    event :study_ice do
      transition apprentice: :frost, if: :has_ice_affinity?
      transition frost: :freeze, if: -> { spell_power > 75 && knows_spell?(:ice_lance) }
      transition freeze: :blizzard, if: -> { spell_power > 150 && ice_mastery_complete? }
    end

    # Arcane progression
    event :study_arcane do
      transition apprentice: :missile, if: :has_arcane_affinity?
      transition missile: :explosion, if: -> { spell_power > 75 && knows_spell?(:arcane_blast) }
      transition explosion: :singularity, if: -> { spell_power > 150 && arcane_mastery_complete? }
    end

    # Become archmage
    event :transcend do
      transition %i[inferno blizzard singularity] => :archmage, if: :worthy_of_archmage?
    end

    before_transition any => any do |mage, transition|
      mage.update_spell_list(transition.to)
    end
  end

  # Spell casting state
  state_machine :casting_state, initial: :ready do
    state :ready
    state :preparing
    state :channeling
    state :releasing
    state :cooldown

    event :begin_cast do
      transition ready: :preparing, if: :has_target?
    end

    event :channel do
      transition preparing: :channeling, if: :channel_started?
    end

    event :release do
      transition channeling: :releasing
    end

    event :complete do
      transition releasing: :cooldown
    end

    event :reset do
      transition cooldown: :ready, if: :cooldown_expired?
    end

    after_transition to: :releasing, &:cast_spell!
  end

  # Mage-specific methods
  def safe_to_meditate?
    !in_combat? && !enemies_nearby?
  end

  def regain_composure?
    focus > 50
  end

  def iron_will?
    has_trait?(:iron_will) || focus > 150
  end

  def concentration_check?
    rand(100) < focus
  end

  def begin_mana_regeneration
    @regenerating_mana = true
  end

  def has_fire_affinity?
    @affinities&.include?(:fire)
  end

  def has_ice_affinity?
    @affinities&.include?(:ice)
  end

  def has_arcane_affinity?
    @affinities&.include?(:arcane)
  end

  def knows_spell?(spell_name)
    @known_spells[spell_name] == true
  end

  def fire_mastery_complete?
    @masteries && @masteries[:fire] >= 100
  end

  def ice_mastery_complete?
    @masteries && @masteries[:ice] >= 100
  end

  def arcane_mastery_complete?
    @masteries && @masteries[:arcane] >= 100
  end

  def worthy_of_archmage?
    level >= 50 && completed_all_trials?
  end

  def update_spell_list(school)
    # Update available spells based on school
  end

  def has_target?
    @current_target != nil
  end

  def channel_started?
    @channel_start_time != nil
  end

  def cooldown_expired?
    @cooldown_end_time && Time.now > @cooldown_end_time
  end

  def cast_spell!
    # Execute the spell
  end

  def in_combat?
    status == 'combat'
  end

  def enemies_nearby?
    false
  end

  def has_trait?(trait)
    @traits&.include?(trait)
  end

  def completed_all_trials?
    @trials_completed && @trials_completed.size >= 5
  end
end
