# frozen_string_literal: true

require 'state_machines-diagram'
require 'mermaid'

module StateMachines
  module Mermaid
    module Renderer
      extend self

      # An alias of the generated form; a plain id of that form is aliased too,
      # so an alias never names another state.
      HEX_ALIAS = /\Astate_(?:\h\h)+\z/

      # Cache recent metadata so we can enhance the Mermaid output with
      # condition/callback details when the caller requests it.
      def reset_metadata!
        @last_state_metadata = nil
        @last_transition_metadata = nil
        @last_state_id_map = nil
      end

      # The new simplified approach - leverages the diagram gem's semantic structure
      def draw_machine(machine, io: $stdout, **options)
        reset_metadata!
        diagram = build_state_diagram(machine, options)
        output_diagram(diagram, io, options)
        diagram
      end
      
      def build_state_diagram(machine, options)
        builder = StateMachines::Diagram::Builder.new(machine, options)
        diagram = builder.build

        @last_state_metadata = builder.state_metadata
        @last_transition_metadata = builder.transition_metadata

        diagram
      end
      
      # The state, the transitions into or out of it, and the states at
      # their other end
      def draw_state(state, graph, options = {}, io = $stdout)
        reset_metadata!
        diagram = build_state_diagram(state.machine, options)
        state_id = diagram_state_id(state)
        io.puts(render_mermaid(diagram, options, focus: [state_id]) do |transition, _metadata|
          [transition.source_state_id, transition.target_state_id].include?(state_id)
        end)
        diagram
      end

      # The transitions the event performs and the states they connect
      def draw_event(event, graph, options = {}, io = $stdout)
        reset_metadata!
        diagram = build_state_diagram(event.machine, options)
        event_name = event.name.to_s
        io.puts(render_mermaid(diagram, options) { |_transition, metadata| metadata[:event] == event_name })
        diagram
      end
      
      # The core method - just delegates to the mermaid gem's to_mermaid method
      def output_diagram(diagram, io, options)
        mermaid_syntax = render_mermaid(diagram, options)
        io.puts mermaid_syntax
        mermaid_syntax
      end

      private

      # Text Mermaid shows as it is: model text never reaches its grammar raw.
      # Characters outside the mermaid gem's safe set become numeric entities
      # (#58;), which Mermaid decodes when it draws; spaces at either end too,
      # since the grammar trims them.
      def mermaid_text(value)
        encoded = value.to_s.each_char.map { |char| char.match?(::Mermaid::Renderer::SAFE) ? char : "##{char.ord};" }.join
        encoded.sub(/\A +/) { |spaces| '#32;' * spaces.size }.sub(/ +\z/) { |spaces| '#32;' * spaces.size }
      end

      # The builder's state id (Builder#state_id)
      def diagram_state_id(state)
        state.name ? state.name.to_s : 'nil_state'
      end

      # Renders the diagram, or with a block only the transitions it keeps
      # (given each transition and its builder metadata), the states they
      # connect, and the +focus+ states.
      def render_mermaid(diagram, options, focus: [], &keep)
        return diagram.to_mermaid unless @last_transition_metadata

        lines = ["stateDiagram-v2"]
        state_id_map = mermaid_state_id_map(diagram)

        # The builder records one metadata entry per transition, in order
        transitions = diagram.transitions.zip(@last_transition_metadata)
        states = diagram.states
        if keep
          transitions = transitions.select { |transition, metadata| keep.call(transition, metadata) }
          shown = transitions.flat_map { |transition, _| [transition.source_state_id, transition.target_state_id] } | focus
          states = states.select { |state| shown.include?(state.id) }
        end

        states.each do |state|
          fragment = render_state_fragment(state, state_id_map.fetch(state.id))
          lines << "  #{fragment}" if fragment && !fragment.empty?

          metadata = @last_state_metadata[state.id] || {}
          lines << "  [*] --> #{state_id_map.fetch(state.id)}" if metadata[:type] == 'initial'
          lines << "  #{state_id_map.fetch(state.id)} --> [*]" if metadata[:type] == 'final'
        end

        transitions.each do |transition, metadata|
          lines << "  #{render_transition_line(transition, metadata, options)}"
        end

        lines.join("\n")
      end

      def render_transition_line(transition, metadata, options)
        from_node = format_node_id(transition.source_state_id)
        to_node = format_node_id(transition.target_state_id)

        label_text = ''

        base_label = transition.label
        label_text = base_label if base_label && !base_label.empty?

        guard_fragment = ''
        if options[:show_conditions] && metadata
          condition_tokens = build_condition_tokens(metadata[:conditions])
          guard_fragment = "[#{condition_tokens.join(' && ')}]" if condition_tokens.any?
        end

        action_fragment = ''
        if options[:show_callbacks] && metadata
          callback_tokens = build_callback_tokens(metadata[:callbacks])
          action_fragment = "/ #{callback_tokens.join(', ')}" if callback_tokens.any?
        end

        parts = []
        parts << label_text unless label_text.empty?
        parts << guard_fragment unless guard_fragment.empty?
        parts << action_fragment unless action_fragment.empty?
        label = parts.join(' ')

        if label.empty?
          "#{from_node} --> #{to_node}"
        else
          "#{from_node} --> #{to_node} : #{mermaid_text(label)}"
        end
      end

      def build_condition_tokens(conditions)
        return [] unless conditions.is_a?(Hash)

        %i[if unless if_state unless_state if_all_states unless_all_states if_any_state unless_any_state].flat_map do |kind|
          Array(conditions[kind]).filter_map do |token|
            "#{kind} #{token}" unless token.nil? || token.to_s.empty?
          end
        end
      end

      def build_callback_tokens(callbacks)
        return [] unless callbacks.is_a?(Hash)

        tokens = []
        callbacks.each do |type, names|
          Array(names).each do |name|
            next if name.nil? || name.to_s.empty?
            tokens << "#{type} #{format_callback_reference(name)}"
          end
        end
        tokens
      end

      def format_callback_reference(callback)
        case callback
        when Proc, Method
          StateMachines::Diagram::Builder.callable_label(callback)
        else
          callback.to_s
        end
      end

      def format_node_id(node_id)
        return '[*]' if node_id == '*'

        @last_state_id_map.fetch(node_id)
      end

      def mermaid_state_id_map(diagram)
        @last_state_id_map ||= diagram.states.each_with_object({}) do |state, map|
          map[state.id] = safe_state_id(state.id)
        end
      end

      # A state id Mermaid reads as a plain name stays itself. Any other id,
      # a keyword of the state grammar included, is aliased by its bytes in
      # hex, which keeps the alias stable whatever other states exist.
      def safe_state_id(state_id)
        value = state_id.to_s
        return value if value.match?(::Mermaid::Renderer::PLAIN) && !value.match?(HEX_ALIAS) &&
                        !::Mermaid::Renderers::StateRenderer::RESERVED.include?(value.downcase)

        "state_#{value.unpack1('H*')}"
      end

      def render_state_fragment(state, rendered_id)
        label = state.label || state.id
        return "#{rendered_id} : #{mermaid_text(label)}" if rendered_id == state.id

        "state #{mermaid_string(label)} as #{rendered_id}"
      end

      def mermaid_string(value)
        %("#{mermaid_text(value)}")
      end
    end
  end
end
