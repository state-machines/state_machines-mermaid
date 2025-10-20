# frozen_string_literal: true

# Regiment with formation and morale states
class Regiment
  attr_accessor :morale, :soldiers, :commander, :supplies, :casualties, :battle_experience, :threats, :enemy_positions,
                :immediate_threats, :enemy_activity_level, :defending_critical_position, :battle_start_time, :pike_wall_ready

  def initialize
    @morale = 100
    @soldiers = 100
    @supplies = 100
    @casualties = 0
    @battle_experience = 0
  end

  state_machine :formation, initial: :column do
    state :column do
      def movement_speed
        2.0
      end

      def defense_rating
        1.0
      end
    end

    state :line do
      def firepower
        3.0
      end

      def defense_rating
        1.5
      end
    end

    state :square do
      def cavalry_defense
        5.0
      end

      def movement_speed
        0.5
      end
    end

    state :wedge do
      def charge_bonus
        4.0
      end

      def breakthrough_chance
        0.7
      end
    end

    state :scattered do
      def cohesion
        0.1
      end

      def rally_difficulty
        10
      end
    end

    state :circle do
      def all_around_defense
        3.0
      end

      def surrounded_bonus
        2.0
      end
    end

    event :deploy do
      transition column: :line, if: :sufficient_space?
    end

    event :form_square do
      transition %i[column line] => :square, if: :cavalry_threat?
      transition wedge: :square, if: :emergency_defense?
    end

    event :form_wedge do
      transition %i[column line] => :wedge, if: -> { morale > 70 && commander_present? }
    end

    event :form_circle do
      transition %i[line square] => :circle, if: :surrounded?
    end

    event :break_formation do
      transition any - :scattered => :scattered, if: -> { morale < 20 || casualties > 50 }
    end

    event :rally do
      transition scattered: :column, if: -> { commander_alive? && morale > 40 }
    end

    event :reform do
      transition %i[square wedge circle] => :line, unless: :under_immediate_threat?
    end

    before_transition any => :scattered, &:apply_panic_casualties

    after_transition to: :square, &:prepare_pikes
  end

  # Supply state
  state_machine :supply_state, initial: :supplied do
    state :supplied do
      def combat_effectiveness
        1.0
      end
    end

    state :low_supplies do
      def combat_effectiveness
        0.8
      end
    end

    state :foraging do
      def vulnerable_to_ambush?
        true
      end
    end

    state :starving do
      def combat_effectiveness
        0.4
      end

      def desertion_rate
        0.1
      end
    end

    event :consume_supplies do
      transition supplied: :low_supplies, if: -> { supplies < 30 }
      transition low_supplies: :starving, if: -> { supplies <= 0 }
    end

    event :send_foragers do
      transition %i[low_supplies starving] => :foraging, if: :safe_to_forage?
    end

    event :resupply do
      transition %i[low_supplies foraging starving] => :supplied
    end

    after_transition on: :resupply, to: :supplied do |regiment|
      regiment.supplies = 100
    end

    event :foraging_success do
      transition foraging: :low_supplies
    end

    after_transition on: :foraging_success, to: :low_supplies do |regiment|
      regiment.supplies += 20
    end
  end

  # Battle readiness
  state_machine :readiness, initial: :fresh do
    state :fresh
    state :engaged
    state :exhausted
    state :victorious
    state :routed

    event :enter_battle do
      transition fresh: :engaged
      transition exhausted: :engaged, if: :desperate_defense?
    end

    event :win_engagement do
      transition engaged: :victorious, if: -> { morale > 60 && casualties < 30 }
    end

    event :lose_engagement do
      transition engaged: :routed, if: -> { morale < 30 || casualties > 60 }
    end

    event :exhaust do
      transition engaged: :exhausted, if: -> { battle_duration > 480 }
    end

    event :rest do
      transition %i[exhausted victorious] => :fresh
    end
  end

  def sufficient_space?
    true # Check battlefield conditions
  end

  def cavalry_threat?
    @threats&.include?(:cavalry)
  end

  def emergency_defense?
    morale < 40 && surrounded?
  end

  def surrounded?
    @enemy_positions && @enemy_positions.count >= 3
  end

  def commander_present?
    commander&.alive? && commander.with_regiment?
  end

  def commander_alive?
    commander&.alive?
  end

  def under_immediate_threat?
    @immediate_threats && !@immediate_threats.empty?
  end

  def apply_panic_casualties
    @casualties += soldiers * 0.1
  end

  def prepare_pikes
    @pike_wall_ready = true
  end

  def safe_to_forage?
    !surrounded? && @enemy_activity_level < 3
  end

  def desperate_defense?
    @defending_critical_position
  end

  def battle_duration
    @battle_start_time ? Time.now - @battle_start_time : 0
  end
end
