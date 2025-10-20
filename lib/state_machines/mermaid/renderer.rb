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
        label = parts.join(' ').strip

        if label.empty?
          "#{from_node} --> #{to_node}"
        else
          "#{from_node} --> #{to_node} : #{label}"
        end
      end

      def build_condition_tokens(conditions)
        return [] unless conditions.is_a?(Hash)

        tokens = []
        Array(conditions[:if]).each do |token|
          next if token.nil? || token.to_s.empty?
          tokens << "if #{token}"
        end
        Array(conditions[:unless]).each do |token|
          next if token.nil? || token.to_s.empty?
          tokens << "unless #{token}"
        end
        tokens
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
        when Symbol, String
          callback.to_s
        when Proc, Method
          if callback.respond_to?(:source_location) && callback.source_location
            file, line = callback.source_location
            filename = File.basename(file) if file
            "lambda@#{filename}:#{line}"
          else
            'lambda'
          end
        else
          callback.to_s
        end
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
