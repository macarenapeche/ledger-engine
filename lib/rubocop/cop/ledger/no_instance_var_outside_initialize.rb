# frozen_string_literal: true

module RuboCop
  module Cop
    module Ledger
      # Reference constructor args through a private `attr_reader`, not `@ivars`, outside
      # `initialize`. Assign in `initialize`; read everywhere else via the reader.
      #
      # @example
      #   # bad
      #   def call
      #     resolve(@from)
      #   end
      #
      #   # good
      #   def call
      #     resolve(from)
      #   end
      #   private
      #   attr_reader :from
      class NoInstanceVariableOutsideInitialize < Base
        MSG = "Use a private attr_reader instead of reading %<ivar>s directly outside initialize."

        # Only flags reads (`:ivar` nodes). Assignments and memoization (`@x ||= ...`) are
        # untouched, so `initialize` and any legitimate memo still pass.
        def on_ivar(node)
          return if node.each_ancestor(:def).any? { |def_node| def_node.method?(:initialize) }

          add_offense(node, message: format(MSG, ivar: node.source))
        end
      end
    end
  end
end
