# frozen_string_literal: true

require 'state_machines-diagram'
require 'mermaid'

module StateMachines
  module Mermaid
    module Renderer
      extend self
      
      # Cache recent metadata so we can enhance the Mermaid output with
      # condition/callback details when the caller requests it.
      def reset_metadata!
        @last_state_metadata = nil
        @last_transition_metadata = nil
        @last_transition_metadata_map = nil
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
        @last_transition_metadata_map = nil

        diagram
      end
      
      def draw_state(state, graph, options = {}, io = $stdout)
        reset_metadata!
        diagram = build_state_diagram(state.machine, options)
        mermaid_syntax = render_mermaid(diagram, options)
        # Filter to show only relevant transitions for this state
        filtered_lines = filter_mermaid_for_state(mermaid_syntax, state.name.to_s)
        io.puts filtered_lines
        diagram
      end
      
      def draw_event(event, graph, options = {}, io = $stdout)
        reset_metadata!
        diagram = build_state_diagram(event.machine, options)
        mermaid_syntax = render_mermaid(diagram, options)
        # Filter to show only transitions triggered by this event
        filtered_lines = filter_mermaid_for_event(mermaid_syntax, event.name.to_s)
        io.puts filtered_lines
        diagram
      end
      
      # The core method - just delegates to the mermaid gem's to_mermaid method
      def output_diagram(diagram, io, options)
        mermaid_syntax = render_mermaid(diagram, options)
        io.puts mermaid_syntax
        mermaid_syntax
      end

      private

      def transition_metadata_map
        @last_transition_metadata_map ||= Array(@last_transition_metadata).each_with_object({}) do |data, memo|
          transition = data[:transition]
          memo[transition] = data if transition
        end
      end

      def render_mermaid(diagram, options)
        return diagram.to_mermaid unless @last_transition_metadata

        lines = ["stateDiagram-v2"]

        diagram.states.each do |state|
          fragment = state.respond_to?(:to_mermaid_fragment) ? state.to_mermaid_fragment : state.id
          lines << "  #{fragment}" if fragment && !fragment.empty?
        end

        diagram.transitions.each do |transition|
          metadata = transition_metadata_map[transition]
          lines << "  #{render_transition_line(transition, metadata, options)}"
        end

        lines.join("\n")
      end

      def render_transition_line(transition, metadata, options)
        from_node = format_node_id(transition.source_state_id)
        to_node = format_node_id(transition.target_state_id)

        label_parts = []

        label = transition.label
        label_parts << label if label && !label.empty?

        if options[:show_conditions] && metadata
          condition_tokens = build_condition_tokens(metadata[:conditions])
          label_parts << "(if: #{condition_tokens.join(' && ')})" if condition_tokens.any?
        end

        if options[:show_callbacks] && metadata
          callback_tokens = build_callback_tokens(metadata[:callbacks])
          label_parts << "(action: #{callback_tokens.join(', ')})" if callback_tokens.any?
        end

        label_text = label_parts.join(' ')
        label_text = nil if label_text.empty?

        if label_text
          "#{from_node} --> #{to_node} : #{label_text}"
        else
          "#{from_node} --> #{to_node}"
        end
      end

      def build_condition_tokens(conditions)
        return [] unless conditions.is_a?(Hash)

        tokens = []
        Array(conditions[:if]).each do |token|
          next if token.nil? || token.to_s.empty?
          tokens << token.to_s
        end
        Array(conditions[:unless]).each do |token|
          next if token.nil? || token.to_s.empty?
          tokens << "!#{token}"
        end
        tokens
      end

      def build_callback_tokens(callbacks)
        return [] unless callbacks.is_a?(Hash)

        tokens = []
        callbacks.each do |type, names|
          Array(names).each do |name|
            next if name.nil? || name.to_s.empty?
            tokens << "#{type}: #{name}"
          end
        end
        tokens
      end

      def format_node_id(node_id)
        node_id == '*' ? '[*]' : node_id
      end

      def filter_mermaid_for_state(mermaid_syntax, state_name)
        lines = mermaid_syntax.split("\n")
        relevant_lines = lines.select do |line|
          line.include?(state_name) || line.start_with?("stateDiagram")
        end
        relevant_lines.join("\n")
      end
      
      def filter_mermaid_for_event(mermaid_syntax, event_name)
        lines = mermaid_syntax.split("\n")
        relevant_lines = lines.select do |line|
          line.include?(event_name) || line.start_with?("stateDiagram")
        end
        relevant_lines.join("\n")
      end
    end
  end
end
