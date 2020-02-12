class Mare::Program
  getter libraries

  def initialize
    @libraries = [] of Library
  end

  # TODO: Remove these aliases and make passes work at the library level
  def imports; libraries.flat_map(&.imports) end
  def types;   libraries.flat_map(&.types)   end
  def aliases; libraries.flat_map(&.aliases) end

  class Library
    getter types
    getter aliases
    getter imports
    property! source_library : Source::Library

    def initialize
      @types = [] of Type
      @aliases = [] of TypeAlias
      @imports = [] of Import
    end

    # TODO: Remove this and meet this need in a less hacky way.
    def clear_lists
      @types.clear
      @aliases.clear
      @imports.clear
    end

    def make_link
      Link.new(source_library.path)
    end

    struct Link
      getter path : String
      def initialize(@path)
      end
      def resolve(ctx : Compiler::Context)
        ctx.program.libraries.find(&.source_library.path.==(@path)).not_nil!
      end
    end
  end

  class Import
    property ident : (AST::Identifier | AST::LiteralString)
    property names : AST::Group?
    property! resolved : Library

    def initialize(@ident, @names = nil)
    end
  end

  class TypeAlias
    property ident : AST::Identifier
    property target : AST::Identifier

    getter metadata

    def initialize(@ident, @target)
      @metadata = Hash(Symbol, Int32 | Bool).new # TODO: should be UInt64?
    end

    def inspect(io : IO)
      io << "#<#{self.class} #{@ident.value}: #{@target.value}>"
    end

    def add_tag(tag : Symbol)
      raise NotImplementedError.new(self)
    end

    def has_tag?(tag : Symbol)
      false # not implemented
    end

    def make_link(library : Library)
      make_link(library.make_link)
    end
    def make_link(library : Library::Link)
      Link.new(library, ident.value)
    end

    struct Link
      getter library : Library::Link
      getter name : String
      def initialize(@library, @name)
      end
      def resolve(ctx : Compiler::Context)
        @library.resolve(ctx).aliases.find(&.ident.value.==(@name)).not_nil!
      end
    end
  end

  class Type
    property cap : AST::Identifier
    property ident : AST::Identifier
    property params : AST::Group?

    getter metadata
    getter functions

    KNOWN_TAGS = [
      :abstract,
      :actor,
      :allocated,
      :hygienic,
      :no_desc,
      :numeric,
      :private,
    ]

    def initialize(@cap, @ident, @params = nil)
      @functions = [] of Function
      @tags = Set(Symbol).new
      @metadata = Hash(Symbol, UInt64 | Bool).new
    end

    def inspect(io : IO)
      io << "#<#{self.class} #{@ident.value}>"
    end

    def find_func?(func_name)
      @functions
        .find { |f| f.ident.value == func_name && !f.has_tag?(:hygienic) }
    end

    def find_func!(func_name)
      @functions
        .find { |f| f.ident.value == func_name && !f.has_tag?(:hygienic) }
        .not_nil!
    end

    def add_tag(tag : Symbol)
      raise NotImplementedError.new(tag) unless KNOWN_TAGS.includes?(tag)
      @tags.add(tag)
    end

    def has_tag?(tag : Symbol)
      raise NotImplementedError.new(tag) unless KNOWN_TAGS.includes?(tag)
      @tags.includes?(tag)
    end

    def tags
      @tags.to_a.sort
    end

    def is_concrete?
      !has_tag?(:abstract)
    end

    def is_instantiable?
      has_tag?(:allocated) && is_concrete?
    end

    def const_u64(name) : UInt64
      f = find_func!(name)
      raise "#{ident.value}.#{name} not a constant" unless f.has_tag?(:constant)

      f.body.not_nil!.terms.last.as(AST::LiteralInteger).value.to_u64
    end

    def const_bool(name) : Bool
      f = find_func!(name)
      raise "#{ident.value}.#{name} not a constant" unless f.has_tag?(:constant)

      case f.body.not_nil!.terms.last.as(AST::Identifier).value
      when "True" then true
      when "False" then false
      else raise NotImplementedError.new(f.body.not_nil!.to_a)
      end
    end

    def const_u64_eq?(name, value : UInt64) : Bool
      f = find_func?(name)
      return false unless f && f.has_tag?(:constant)

      term = f.body.try(&.terms[-1]?)
      term.is_a?(AST::LiteralInteger) && term.value == value
    end

    def const_bool_true?(name) : Bool
      f = find_func?(name)
      return false unless f && f.has_tag?(:constant)

      term = f.body.try(&.terms[-1]?)
      term.is_a?(AST::Identifier) && term.value == "True"
    end

    def make_link(library : Library)
      make_link(library.make_link)
    end
    def make_link(library : Library::Link)
      Link.new(library, ident.value)
    end

    struct Link
      getter library : Library::Link
      getter name : String
      def initialize(@library, @name)
      end
      def resolve(ctx : Compiler::Context)
        @library.resolve(ctx).types.find(&.ident.value.==(@name)).not_nil!
      end
    end
  end

  class Function
    property ast : AST::Function
    def cap; ast.cap end
    def cap=(x); ast.cap = x end
    def ident; ast.ident end
    def ident=(x); ast.ident = x end
    def params; ast.params end
    def params=(x); ast.params = x end
    def ret; ast.ret end
    def ret=(x); ast.ret = x end
    def body; ast.body end
    def body=(x); ast.body = x end
    def yield_out; ast.yield_out end
    def yield_out=(x); ast.yield_out = x end
    def yield_in; ast.yield_in end
    def yield_in=(x); ast.yield_in = x end

    getter metadata : Hash(Symbol, String)

    KNOWN_TAGS = [
      :async,
      :compiler_intrinsic,
      :constant,
      :constructor,
      :copies,
      :ffi,
      :field,
      :hygienic,
      :is,
      :it,
    ]

    def initialize(*args)
      @ast = AST::Function.new(*args)
      @tags = Set(Symbol).new
      @metadata = Hash(Symbol, String).new
    end

    def inspect(io : IO)
      io << "#<"
      @tags.to_a.inspect(io)
      @metadata.inspect(io)
      io << " fun"
      io << " " << cap.value
      io << " " << ident.value
      params ? (io << " "; params.not_nil!.to_a.inspect(io)) : (io << " []")
      ret    ? (io << " "; ret.not_nil!.to_a.inspect(io))    : (io << " _")
      body   ? (io << ": "; body.not_nil!.to_a.inspect(io))  : (io << " _")
      io << ">"
    end

    def dup_init
      @tags = @tags.dup
      @metadata = @metadata.dup
    end

    def dup
      super.tap(&.dup_init)
    end

    def add_tag(tag : Symbol)
      raise NotImplementedError.new(tag) unless KNOWN_TAGS.includes?(tag)
      @tags.add(tag)
    end

    def has_tag?(tag : Symbol)
      raise NotImplementedError.new(tag) unless KNOWN_TAGS.includes?(tag)
      @tags.includes?(tag)
    end

    def tags
      @tags.to_a.sort
    end

    def param_count
      params.try { |group| group.terms.size } || 0
    end
  end
end
