require 'sass/tree/node'

module Sass::Tree
  # A dynamic node representing a Sass `@if` statement.
  #
  # {IfNode}s are a little odd, in that they also represent `@else` and `@else if`s.
  # This is done as a linked list:
  # each {IfNode} has a link (\{#else}) to the next {IfNode}.
  #
  # @see Sass::Tree
  class IfNode < Node
    # The next {IfNode} in the if-else list, or `nil`.
    #
    # @return [IfNode]
    attr_accessor :else

    # @param expr [Script::Expr] The conditional expression.
    #   If this is nil, this is an `@else` node, not an `@else if`
    def initialize(expr)
      @expr = expr
      @last_else = self
      super()
    end

    # Append an `@else` node to the end of the list.
    #
    # @param node [IfNode] The `@else` node to append
    def add_else(node)
      @last_else.else = node
      @last_else = node
    end

    # @see Node#options=
    def options=(options)
      super
      self.else.options = options if self.else
    end

    # @see Node#_around_dump
    def _around_dump
      old_else = @else
      old_last_else = @last_else
      @else = Sass::Util.dump(@else)
      @last_else = (self == @last_else ? nil : Sass::Util.dump(@last_else))
      super
    ensure
      @else = old_else
      @last_else = old_last_else
    end

    # @see Node#_after_load
    def _after_load
      super
      @else = Sass::Util.load(@else)
      @last_else = (@last_else ? Sass::Util.load(@last_else) : self)
    end

    protected

    # @see Node#to_src
    def to_src(tabs, opts, fmt, is_else = false)
      name =
        if !is_else; "if"
        elsif @expr; "else if"
        else; "else"
        end
      str = "#{'  ' * tabs}@#{name}"
      str << " #{@expr.to_sass(opts)}" if @expr
      str << children_to_src(tabs, opts, fmt)
      str << @else.send(:to_src, tabs, opts, fmt, true) if @else
      str
    end

    # Runs the child nodes if the conditional expression is true;
    # otherwise, tries the \{#else} nodes.
    #
    # @param environment [Sass::Environment] The lexical environment containing
    #   variable and mixin values
    # @return [Array<Tree::Node>] The resulting static nodes
    # @see Sass::Tree
    def _perform(environment)
      environment = Sass::Environment.new(environment)
      return perform_children(environment) if @expr.nil? || @expr.perform(environment).to_bool
      return @else.perform(environment) if @else
      []
    end
  end
end
