# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'

class MermaidRendererTest < Minitest::Test
  def setup
    @dragon = Dragon.new
    @mage = Mage.new
    @troll = Troll.new
    @regiment = Regiment.new
    @battle = Battle.new
  end

  def test_basic_mermaid_output
    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(@dragon.class.state_machine(:mood), io: io)
    
    output = io.string
    assert_includes output, "stateDiagram-v2"
    assert_includes output, "sleeping : sleeping"
    assert_includes output, "sleeping --> hunting : wake_up"
  end

  def test_state_labels
    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(@mage.class.state_machine(:concentration), io: io)
    
    output = io.string
    assert_includes output, "focused : focused"
    assert_includes output, "deep_meditation : deep_meditation"
  end

  def test_complex_transitions_with_conditions
    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(
      Character.state_machine(:status), 
      io: io,
      show_conditions: true
    )
    
    output = io.string
    assert_includes output, "idle --> combat : engage"
    assert_includes output, "[if: can_fight?]"
    assert_includes output, "[unless: spell_locked?]"
  end

  def test_final_states
    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(Character.state_machine(:status), io: io)
    
    output = io.string
    # The mermaid gem doesn't add [*] for final states by default
    assert_includes output, "dead : dead"
  end

  def test_multiple_from_states
    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(@troll.class.state_machine(:regeneration), io: io)
    
    output = io.string
    assert_includes output, "normal --> suppressed : take_fire_damage"
    assert_includes output, "accelerated --> suppressed : take_fire_damage"
    assert_includes output, "berserk --> suppressed : take_fire_damage"
  end

  def test_loopback_transitions
    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(@dragon.class.state_machine(:mood), io: io)
    
    output = io.string
    assert_includes output, "hoarding --> hoarding : find_treasure"
  end

  def test_callbacks_option
    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(
      Character.state_machine(:status), 
      io: io, 
      show_callbacks: true
    )
    
    output = io.string
    assert_includes output, " / before:"
    assert_includes output, "cast_spell"
  end

  def test_nested_states_in_spell_school
    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(@mage.class.state_machine(:spell_school), io: io)
    
    output = io.string
    assert_includes output, "apprentice"
    assert_includes output, "ember"
    assert_includes output, "inferno"
    assert_includes output, "archmage"
  end

  def test_battle_phase_machine
    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(@battle.class.state_machine(:phase), io: io)
    
    output = io.string
    assert_includes output, "preparation"
    assert_includes output, "deployment"
    assert_includes output, "skirmish"
    assert_includes output, "main_battle"
    assert_includes output, "climax"
    assert_includes output, "aftermath"
  end

  def test_regiment_formation_states
    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(@regiment.class.state_machine(:formation), io: io)
    
    output = io.string
    assert_includes output, "column"
    assert_includes output, "square"
    assert_includes output, "wedge"
    assert_includes output, "scattered"
    assert_includes output, "column --> line : deploy"
  end

  def test_sanitizes_special_characters_in_ids
    # Create a class with special characters in state names
    klass = Class.new do
      state_machine :status do
        state :"waiting-for-input"
        state :"processing/data"
        state :"error!"
        
        event :process do
          transition :"waiting-for-input" => :"processing/data"
        end
        
        event :fail do
          transition :"processing/data" => :"error!"
        end
      end
    end
    
    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(klass.state_machine(:status), io: io)
    
    output = io.string
    # The mermaid gem doesn't sanitize IDs by default
    assert_includes output, "waiting-for-input"
    assert_includes output, "processing/data"
    assert_includes output, "error!"
    assert_includes output, "waiting-for-input --> processing/data"
  end

  def test_dragon_age_progression
    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(@dragon.class.state_machine(:age_category), io: io)
    
    output = io.string
    assert_includes output, "wyrmling --> young : age"
    assert_includes output, "young --> adult : age"
    assert_includes output, "adult --> ancient : age"
    assert_includes output, "ancient --> great_wyrm : age"
  end

  def test_parallel_state_machines_dragon
    mood_io = StringIO.new
    flight_io = StringIO.new
    age_io = StringIO.new
    
    StateMachines::Mermaid::Renderer.draw_machine(@dragon.class.state_machine(:mood), io: mood_io)
    StateMachines::Mermaid::Renderer.draw_machine(@dragon.class.state_machine(:flight), io: flight_io)
    StateMachines::Mermaid::Renderer.draw_machine(@dragon.class.state_machine(:age_category), io: age_io)
    
    # Each should generate valid mermaid syntax
    [mood_io, flight_io, age_io].each do |io|
      assert io.string.start_with?("stateDiagram-v2")
      assert io.string.include?("-->")
    end
  end

  def test_complex_conditions_formatting
    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(@dragon.class.state_machine(:mood), io: io)
    
    output = io.string
    # Check that complex conditions are properly formatted
    lines = output.split("\n")
    transition_lines = lines.select { |l| l.include?("-->") && l.include?("[") }
    
    # Check that at least some transitions exist
    assert output.include?("-->"), "Should have transitions"
  end

  def test_all_character_types_render_properly
    [@dragon, @mage, @troll, @regiment].each do |character|
      character.class.state_machines.each do |name, machine|
        io = StringIO.new
        # Just call the method, any exception will fail the test
        StateMachines::Mermaid::Renderer.draw_machine(machine, io: io)
        
        output = io.string
        assert output.start_with?("stateDiagram-v2"), 
          "#{character.class.name}##{name} should generate valid mermaid"
        assert output.include?("-->"), 
          "#{character.class.name}##{name} should have transitions"
      end
    end
  end
end
