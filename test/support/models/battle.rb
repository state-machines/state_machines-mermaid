# frozen_string_literal: true

# Epic battle scenario with multiple interacting state machines
class Battle
  attr_accessor :weather, :terrain, :advantage, :participants, :phase_start_time, :left_flank_secure,
                :right_flank_secure

  def initialize
    @participants = {
      dragons: [],
      mages: [],
      regiments: [],
      heroes: []
    }
    @advantage = 50
  end

  state_machine :phase, initial: :preparation do
    state :preparation do
      def allow_reinforcements?
        true
      end
    end

    state :deployment do
      def can_reposition?
        true
      end
    end

    state :skirmish do
      def casualties_multiplier
        0.5
      end
    end

    state :main_battle do
      def casualties_multiplier
        2.0
      end
    end

    state :climax do
      def heroic_actions_enabled?
        true
      end
    end

    state :aftermath do
      def battle_ended?
        true
      end
    end

    event :begin_deployment do
      transition preparation: :deployment, if: :all_forces_ready?
    end

    event :commence_battle do
      transition deployment: :skirmish
    end

    after_transition on: :commence_battle, to: :skirmish do |battle|
      battle.phase_start_time = Time.now
    end

    event :escalate do
      transition skirmish: :main_battle, if: -> { phase_duration > 300 || heavy_casualties? }
    end

    event :reach_climax do
      transition main_battle: :climax, if: :decisive_moment?
    end

    event :conclude do
      transition %i[skirmish main_battle climax] => :aftermath
    end

    after_transition any => any do |battle, transition|
      battle.log_phase_change(transition)
    end
  end

  # Weather conditions affecting battle
  state_machine :weather, initial: :clear do
    state :clear do
      def visibility
        1000
      end
    end

    state :fog do
      def visibility
        100
      end

      def ranged_penalty
        0.5
      end
    end

    state :rain do
      def movement_penalty
        0.8
      end

      def fire_magic_penalty
        0.6
      end
    end

    state :storm do
      def movement_penalty
        0.5
      end

      def flying_impossible?
        true
      end
    end

    event :weather_change do
      transition clear: %i[fog rain], if: :weather_front_approaching?
      transition fog: %i[clear rain]
      transition rain: %i[storm clear]
      transition storm: :rain
    end
  end

  # Battlefield control
  state_machine :battlefield_control, initial: :contested do
    state :contested
    state :advantage_left
    state :advantage_right
    state :center_breakthrough
    state :encirclement

    event :gain_left do
      transition contested: :advantage_left
    end

    event :gain_right do
      transition contested: :advantage_right
    end

    event :breakthrough do
      transition %i[advantage_left advantage_right] => :center_breakthrough
    end

    event :encircle do
      transition %i[advantage_left advantage_right] => :encirclement, if: :flanks_secured?
    end
  end

  def all_forces_ready?
    participants.values.all? { |forces| forces.any?(&:ready?) }
  end

  def phase_duration
    phase_start_time ? Time.now - phase_start_time : 0
  end

  def heavy_casualties?
    total_casualties > initial_forces * 0.2
  end

  def decisive_moment?
    advantage > 75 || advantage < 25
  end

  def log_phase_change(transition)
    puts "Battle phase changed from #{transition.from} to #{transition.to}"
  end

  def weather_front_approaching?
    rand(100) < 30
  end

  def flanks_secured?
    @left_flank_secure && @right_flank_secure
  end

  def total_casualties
    participants[:regiments].sum(&:casualties)
  end

  def initial_forces
    @initial_forces ||= participants[:regiments].sum(&:soldiers)
  end
end
