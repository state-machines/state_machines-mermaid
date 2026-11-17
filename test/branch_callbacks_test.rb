# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'

# A transition's own callbacks (transition ..., before:/around:/after:) drawn
# where the core runs them among the machine's callbacks
class BranchCallbacksTest < Minitest::Test
  def setup
    @machine = Phoenix.state_machine(:flame)
  end

  def render(**)
    io = StringIO.new
    StateMachines::Mermaid::Renderer.draw_machine(@machine, io: io, **)
    io.string
  end

  def test_branch_callbacks_run_inside_the_machine_ones
    assert_includes render(show_callbacks: true),
                    'ember --> blaze : ignite / before stoke, around channel, before chant (if ritual?), ' \
                    "before gather_heat, around shield, after roar, after scatter_sparks\n"
  end

  def test_each_branch_of_an_event_shows_its_own_callbacks
    output = render(show_conditions: true, show_callbacks: true)

    assert_includes output, 'ash --> ember : rekindle [if feathers_left?] / before stoke, around channel, ' \
                            "before chant (if ritual?), after hatch, after preen, after scatter_sparks, after sing\n"
    assert_includes output, 'ash --> blaze : rekindle / before stoke, around channel, before chant (if ritual?), ' \
                            "before flare, after erupt, after scatter_sparks, after sing\n"
    assert_includes output, 'blaze --> blaze : rekindle / before stoke, around channel, before chant (if ritual?), ' \
                            "around circle, after scatter_sparks, after sing\n"
  end

  def test_a_state_context_transition_keeps_the_order_written
    # around: is written before before:, so smolder wraps dim
    assert_includes render(show_callbacks: true),
                    'blaze --> ash : burn_out / before stoke, around channel, before chant (if ritual?), ' \
                    "around smolder, before dim, after crumble, after scatter_sparks\n"
  end

  def test_branch_callbacks_stay_hidden_without_show_callbacks
    assert_includes render, "ember --> blaze : ignite\n"
  end

  def test_a_branch_drawn_through_the_core_shows_its_callbacks
    event = @machine.events[:burn_out]
    io = StringIO.new
    previous = StateMachines::Machine.instance_variable_get(:@renderer)
    StateMachines::Machine.renderer = StateMachines::Mermaid::Renderer
    event.branches.first.draw(nil, event, [], io)

    # the core passes no options, so the branch draws without callbacks
    assert_includes io.string, "blaze --> ash : burn_out\n"
  ensure
    StateMachines::Machine.renderer = previous
  end

  def test_the_order_drawn_is_the_order_the_core_runs
    phoenix = Phoenix.new
    phoenix.ignite

    drawn = render(show_callbacks: true)[%r{ember --> blaze : ignite / (.*)$}, 1].split(', ')

    assert_equal(phoenix.log.grep_v(/ exit\z/).map { it.delete_suffix(' enter') },
                 drawn.map { it.split[1] })
  end
end
