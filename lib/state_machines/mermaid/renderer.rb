# frozen_string_literal: true

require 'json'
require 'state_machines-diagram'
require 'mermaid'

module StateMachines
  module Mermaid
    # Draws a machine, or the part of it one state, event or branch involves,
    # as a Mermaid state diagram. Everything a draw needs travels with its
    # builder: the renderer keeps no state between draws, so draws from
    # several threads never see each other's diagrams.
    module Renderer
      # An alias of the generated form; a plain id of that form is aliased too,
      # so an alias never names another state.
      HEX_ALIAS = /\Astate_(?:\h\h)+\z/

      extend self

      def draw_machine(machine, io: $stdout, **options)
        builder = Diagram::Builder.new(machine, options)
        builder.build
        output_diagram(builder, io, options)
        builder.diagram
      end

      # The state, the transitions into or out of it, and the states at
      # their other end
      def draw_state(state, _graph, options = {}, io = $stdout)
        builder = Diagram::Builder.new(state.machine, options)
        builder.build_state(state)
        output_diagram(builder, io, options)
        builder.diagram
      end

      # The transitions the event performs and the states they connect
      def draw_event(event, _graph, options = {}, io = $stdout)
        builder = Diagram::Builder.new(event.machine, options)
        builder.build_event(event)
        output_diagram(builder, io, options)
        builder.diagram
      end

      # The transitions one branch performs and the states they connect.
      # The core passes no options (Branch#draw).
      def draw_branch(branch, _graph, event, _valid_states, io = $stdout)
        builder = Diagram::Builder.new(event.machine)
        builder.build_branch(branch, event)
        output_diagram(builder, io, {})
        builder.diagram
      end

      # Writes what +builder+ built as Mermaid and returns the text
      def output_diagram(builder, io, options = {})
        text = render(builder, options)
        io.puts text
        text
      end

      # The Mermaid text for what +builder+ built: front matter with the
      # title, as the mermaid gem writes it, then the diagram
      def render(builder, options = {})
        format = options[:format]
        raise ArgumentError, "unknown format #{format.inspect}; known: mermaid" unless format.nil? || format == :mermaid

        diagram = builder.diagram
        names = diagram.states.to_h { [it.id, safe_state_id(it.id)] }
        [*front_matter(diagram.title), 'stateDiagram-v2',
         *diagram.states.flat_map { state_lines(it, names.fetch(it.id), builder.state_metadata.fetch(it.id)) },
         *builder.transition_metadata.map { transition_line(it, names, options) }].join("\n")
      end

      private

      # YAML is read before entities are, so the title goes in as a JSON
      # string; only Mermaid's own entity placeholders cannot survive the
      # drawing step.
      def front_matter(title)
        return [] if title.nil?
        if title.match?(::Mermaid::Renderer::PLACEHOLDERS)
          raise ArgumentError, "Mermaid cannot show title #{title.inspect}"
        end

        ['---', "title: #{title.to_json}", '---']
      end

      # The declaration, then the initial and final markers: a state can be both
      def state_lines(state, name, metadata)
        lines = ["  #{state_declaration(state, name, metadata[:label])}"]
        lines << "  [*] --> #{name}" if metadata[:initial]
        lines << "  #{name} --> [*]" if metadata[:final]
        lines
      end

      # Mermaid has no empty state name: `state "" as x` does not parse, and
      # `x :` shows x. Refused rather than drawn as another name.
      def state_declaration(state, name, label)
        raise ArgumentError, 'Mermaid cannot show an empty state name' if label.empty?
        return "#{name} : #{mermaid_text(label)}" if name == state.id

        %(state "#{mermaid_text(label)}" as #{name})
      end

      def transition_line(metadata, names, options)
        transition = metadata[:transition]
        line = "  #{names.fetch(transition.source_state_id)} --> #{names.fetch(transition.target_state_id)}"
        label = transition_label(metadata, options)
        label.empty? ? line : "#{line} : #{mermaid_text(label)}"
      end

      # "label [conditions] / callbacks", with conditions and callbacks on request
      def transition_label(metadata, options)
        conditions = options[:show_conditions] ? condition_tokens(metadata[:conditions]) : []
        callbacks = options[:show_callbacks] ? callback_tokens(metadata[:callbacks]) : []
        [metadata[:label], ("[#{conditions.join(' && ')}]" if conditions.any?),
         ("/ #{callbacks.join(', ')}" if callbacks.any?)].compact.reject(&:empty?).join(' ')
      end

      # if/unless conditions one by one, each one term; each state guard as
      # one group under its kind, which says how its requirements combine
      def condition_tokens(conditions)
        conditions.flat_map do |kind, value|
          next value.map { "#{kind} #{Diagram::Labels.condition_term(it)}" } if %i[if unless].include?(kind)

          [Diagram::Labels.state_guard_token(kind, value)]
        end
      end

      def callback_tokens(callbacks)
        callbacks.flat_map { |type, labels| labels.map { "#{type} #{it}" } }
      end

      # Text Mermaid shows as it is: model text never reaches its grammar raw.
      # Characters outside the mermaid gem's safe set become numeric entities
      # (#58;), which Mermaid decodes when it draws; spaces at either end too,
      # since the grammar trims them.
      def mermaid_text(value)
        encoded = value.to_s.each_char.map do |char|
          char.match?(::Mermaid::Renderer::SAFE) ? char : "##{char.ord};"
        end.join
        encoded.sub(/\A +/) { |spaces| '#32;' * spaces.size }.sub(/ +\z/) { |spaces| '#32;' * spaces.size }
      end

      # A state id Mermaid reads as a plain name stays itself. Any other id,
      # a keyword of the state grammar included, is aliased by its bytes in
      # hex, which keeps the alias stable whatever other states exist. So is
      # the nil state's id: it is not the state's name, and drawn as a plain
      # name it would show "nil_state" like the state named so.
      def safe_state_id(state_id)
        return state_id if state_id.match?(::Mermaid::Renderer::PLAIN) && !state_id.match?(HEX_ALIAS) &&
                           state_id != Diagram::Builder::NIL_STATE_ID &&
                           !::Mermaid::Renderers::StateRenderer::RESERVED.include?(state_id.downcase)

        "state_#{state_id.unpack1('H*')}"
      end
    end
  end
end
