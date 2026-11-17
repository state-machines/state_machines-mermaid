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
    assert_includes output, "[if can_fight?]"
    assert_includes output, "[unless spell_locked?]"
  end

  def test_final_states
    klass = Class.new do
      attr_accessor :state

      state_machine :state, initial: :idle do
        event :finish do
          transition idle: :done
        end
      end
    end

    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(klass.state_machine(:state), io: io)
    
    output = io.string
    assert_includes output, "done : done"
    assert_includes output, "[*] --> idle"
    assert_includes output, "done --> [*]"
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
    assert_includes output, " / before"
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
    assert_includes output, 'state "waiting-for-input" as state_77616974696e672d666f722d696e707574'
    assert_includes output, 'state "processing/data" as state_70726f63657373696e672f64617461'
    assert_includes output, 'state "error!" as state_6572726f7221'
    assert_includes output, 'state_77616974696e672d666f722d696e707574 --> state_70726f63657373696e672f64617461'
  end

  def test_aliases_state_grammar_keywords_and_alias_lookalikes
    klass = Class.new do
      attr_accessor :status

      state_machine :status, initial: :idle do
        event :go do
          transition idle: :end
        end

        event :jump do
          transition idle: :state_65
        end
      end
    end

    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(klass.state_machine(:status), io: io)

    output = io.string
    assert_includes output, 'state "end" as state_656e64'
    assert_includes output, 'idle --> state_656e64 : go'
    assert_includes output, 'state "state_65" as state_73746174655f3635'
    refute_match(/^\s+end\b/, output)
  end

  def test_encodes_text_mermaid_would_read_as_syntax
    klass = Class.new do
      attr_accessor :status

      state_machine :status, initial: :idle do
        event :'say "hi"; # now' do
          transition idle: :'a"b'
        end
      end
    end

    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(klass.state_machine(:status), io: io)

    output = io.string
    assert_includes output, 'state "a#34;b" as state_612262'
    assert_includes output, 'idle --> state_612262 : say #34;hi#34;#59; #35; now'
    refute_includes output, '\\"'
  end

  def test_draw_state_keeps_the_transitions_of_an_aliased_state
    klass = Class.new do
      attr_accessor :status

      state_machine :status, initial: :idle do
        event :wait do
          transition idle: :'waiting-for-input'
        end

        event :resume do
          transition 'waiting-for-input': :idle
        end

        event :sleep do
          transition idle: :asleep
        end
      end
    end

    io = StringIO.new
    machine = klass.state_machine(:status)
    StateMachines::Mermaid::Renderer.draw_state(machine.states[:'waiting-for-input'], nil, {}, io)

    output = io.string
    waiting = 'state_77616974696e672d666f722d696e707574'
    assert_includes output, "idle --> #{waiting} : wait"
    assert_includes output, "#{waiting} --> idle : resume"
    refute_includes output, 'asleep'
  end

  def test_draw_event_keeps_only_its_transitions
    klass = Class.new do
      attr_accessor :status

      state_machine :status, initial: :idle do
        event :run do
          transition idle: :running
        end

        event :run_fast do
          transition idle: :sprinting
        end
      end
    end

    io = StringIO.new
    machine = klass.state_machine(:status)
    StateMachines::Mermaid::Renderer.draw_event(machine.events[:run], nil, {}, io)

    output = io.string
    assert_includes output, 'idle --> running : run'
    refute_includes output, 'sprinting'
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

  def test_renders_coordinated_state_guards
    klass = Class.new do
      attr_accessor :state, :gate

      state_machine :gate, initial: :locked do
        event :unlock do
          transition locked: :unlocked
        end
      end

      state_machine :state, initial: :idle do
        event :run do
          transition idle: :running, if_state: { gate: :unlocked }
        end
      end
    end

    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(
      klass.state_machine(:state),
      io: io,
      show_conditions: true
    )

    assert_includes io.string, '[if_state gate=unlocked]'
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
  def test_renders_names_a_diagram_cannot_hold
    klass = Class.new do
      attr_accessor :state

      state_machine :state, initial: :idle do
        state nil, :nil_state

        event :go do
          transition idle: :"*"
        end

        event :" " do
          transition :"*" => nil
        end

        event :"" do
          transition nil => :nil_state
        end
      end
    end

    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(klass.state_machine(:state), io: io)

    output = io.string
    assert_includes output, 'state "*" as state_253261'
    assert_includes output, 'idle --> state_253261 : go'
    assert_includes output, 'state_253261 --> state_6e696c5f7374617465 : #32;'
    assert_includes output, 'state "nil" as state_6e696c5f7374617465'
    assert_includes output, 'state "nil_state" as state_25366536393663356637333734363137343635'
    assert_includes output, "state_6e696c5f7374617465 --> state_25366536393663356637333734363137343635\n"
  end

  def test_a_nil_human_name_falls_back_to_the_name
    klass = Class.new do
      attr_accessor :state

      state_machine :state, initial: :idle do
        state :idle, human_name: ->(*) {}

        event :go, human_name: ->(*) {} do
          transition idle: :done
        end
      end
    end

    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(klass.state_machine(:state), io: io, human_names: true)

    assert_includes io.string, 'idle : idle'
    assert_includes io.string, 'idle --> done : go'
  end

  def test_refuses_an_empty_state_name
    klass = Class.new do
      attr_accessor :state

      state_machine :state, initial: :""
    end

    error = assert_raises(ArgumentError) do
      StateMachines::Mermaid::Renderer.draw_machine(klass.state_machine(:state), io: StringIO.new)
    end
    assert_equal 'Mermaid cannot show an empty state name', error.message
  end

  def test_marks_a_state_both_initial_and_final
    klass = Class.new do
      attr_accessor :state

      state_machine :state, initial: :alone
    end

    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(klass.state_machine(:state), io: io)

    assert_includes io.string, '[*] --> alone'
    assert_includes io.string, 'alone --> [*]'
  end

  def test_keeps_each_state_guard_group_with_its_kind
    klass = Class.new do
      attr_accessor :state, :gate, :alarm

      state_machine :gate, initial: :closed do
        state :open
      end

      state_machine :alarm, initial: :off do
        state :on
      end

      state_machine :state, initial: :idle do
        event :check do
          transition idle: :done, if_any_state: { gate: :open, alarm: :on },
                                  unless_all_states: { gate: :closed, alarm: :off }
        end
      end
    end

    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(klass.state_machine(:state), io: io, show_conditions: true)

    assert_includes io.string,
                    'idle --> done : check [unless_all_states (gate=closed, alarm=off) #38;#38; ' \
                    'if_any_state (gate=open, alarm=on)]'
  end
end
