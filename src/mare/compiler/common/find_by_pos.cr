class Mare::Compiler::Common::FindByPos < Mare::AST::Visitor
  # Given a source position, try to find the AST nodes that contain it.
  # Currently this only works within functions, but could be expanded to types.
  # When found, returns the instance of this class with the reverse_path filled.
  # When not found, returns nil.
  def self.find(ctx : Context, pos : Source::Pos)
    ctx.program.libraries.each do |library|
      library.types.each do |t|
        next unless t.ident.pos.source == pos.source

        t.functions.each do |f|
          next unless f.ident.pos.source == pos.source

          found = find_within(ctx, pos, library, t, f, f.ast)
          return found if found
        end
      end
    end

    nil
  end

  def self.find_within(
    ctx : Context,
    pos : Source::Pos,
    library : Program::Library,
    t : Program::Type?,
    f : Program::Function?,
    node : AST::Node,
  )
    return unless node.span_pos.contains?(pos)

    t_link = t.try(&.make_link(library))
    f_link = f.try(&.make_link(t_link.not_nil!))

    visitor = new(pos, t_link, f_link)
    node.accept(ctx, visitor)
    visitor
  end

  getter pos : Source::Pos
  getter reverse_path : Array(AST::Node)
  getter t_link : Program::Type::Link?
  getter f_link : Program::Function::Link?

  def initialize(@pos, @t_link, @f_link)
    @reverse_path = [] of AST::Node
  end

  def visit_any?(ctx : Context, node : AST::Node)
    node.span_pos.contains?(@pos)
  end

  def visit(ctx : Context, node : AST::Node)
    @reverse_path << node
  end
end
