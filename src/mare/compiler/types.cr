require "./pass/analyze"

##
# WIP: This pass is intended to be a future replacement for the Infer pass,
# but it is still a work in progress and isn't in the main compile path yet.
#
# This pass does not mutate the Program topology.
# This pass does not mutate the AST.
# This pass may raise a compilation error.
# This pass keeps state at the per-type and per-function level.
# This pass produces output state at the per-type and per-function level.
#
module Mare::Compiler::Types
  struct Analysis
    protected getter scope : Program::Function::Link | Program::Type::Link | Program::TypeAlias::Link
    protected getter! for_self : AlgebraicType

    def initialize(@scope, parent : Analysis? = nil)
      @parent = parent ? StructRef(Analysis).new(parent) : nil
      @sequence_number = 0u64

      @by_node = {} of AST::Node => AlgebraicType
      @by_ref = {} of Refer::Info => AlgebraicType
      @type_vars = [] of TypeVariable
      @bindings = Set({Source::Pos, TypeVariable, AlgebraicType}).new
      @constraints = Set({Source::Pos, AlgebraicType, TypeVariable}).new
      @assignments = Set({Source::Pos, TypeVariable, AlgebraicType}).new
      @assertions = Set({Source::Pos, AlgebraicType, AlgebraicType}).new
    end

    def [](node : AST::Node); @by_node[node]; end
    def []?(node : AST::Node); @by_node[node]?; end

    protected def []=(node : AST::Node, alg : AlgebraicType)
      @by_node[node] = alg
    end

    def show_type_variables_list
      String.build { |output|
        @type_vars.each { |var|
          output << "#{var.show}\n"
          @bindings.select(&.[](1).==(var)).each { |pos, _, explicit|
            output << "  := #{explicit.show}\n"
            output << "  #{pos.show.split("\n")[1..-1].join("\n  ")}\n"
          }
          @constraints.select(&.[](2).==(var)).each { |pos, sup, _|
            output << "  <: #{sup.show}\n"
            output << "  #{pos.show.split("\n")[1..-1].join("\n  ")}\n"
          }
          @assignments.select(&.[](1).==(var)).each { |pos, _, sub|
            output << "  |= #{sub.show}\n"
            output << "  #{pos.show.split("\n")[1..-1].join("\n  ")}\n"
          }
          output << "\n"
        }
        @assertions.each { |pos, lhs, rhs|
          output << "  #{lhs.show} :> #{rhs.show}\n"
          output << "  #{pos.show.split("\n")[1..-1].join("\n  ")}\n"
        }
      }
    end

    private def new_type_var(nickname)
      TypeVariable.new(nickname, @scope, @sequence_number += 1).tap { |var|
        @type_vars << var
      }
    end

    private def new_cap_var(nickname)
      CapVariable.new(nickname, @scope, @sequence_number += 1)
    end

    protected def init_type_self(
      params : Array({AST::Term, AlgebraicType?, AlgebraicType?})?
    )
      @for_self = NominalType.new(
        scope.as(Program::Type::Link),
        params.try(&.map { |param, explicit_type, default_type|
          ident, explicit, default = AST::Extract.type_param(param)
          var = new_type_var(ident.value)

          @by_node[param] = var
          @by_node[ident] = var
          @by_node[explicit] = explicit_type.not_nil! if explicit
          @by_node[default] = default_type.not_nil! if default

          @constraints << {explicit.pos, explicit_type.not_nil!, var} if explicit

          var
        }),
      )
    end

    protected def init_func_self(cap : String, pos : Source::Pos)
      @for_self = new_type_var("@").tap { |var|
        self_type = @parent.not_nil!.value.for_self
        self_cap = new_cap_var("@") # TODO: add constraint for func cap
        @bindings << {pos, var, self_type.intersect(self_cap)}
      }.as(AlgebraicType)
    end

    protected def observe_prelude_type(ctx, node, name, cap)
      t_link = ctx.namespace.prelude_type(name)
      @by_node[node] = NominalType.new(t_link).intersect(NominalCap.new(cap))
    end

    protected def observe_assert_bool(ctx, node)
      t_link = ctx.namespace.prelude_type("Bool")
      bool = NominalType.new(t_link).intersect(NominalCap.new("val"))
      rhs = @by_node[node]
      @assertions << {node.pos, bool, rhs}
    end

    protected def observe_self_reference(node, ref)
      @by_node[node] = @by_ref[ref] ||= for_self
    end

    protected def observe_local_reference(node, ref)
      var = @by_ref[ref] ||= new_type_var(ref.name)
      @by_node[node] = var.aliased
    end

    protected def observe_transitive(to_node, from_node)
      @by_node[to_node] = @by_node[from_node]
    end

    protected def observe_assignment(node, ref)
      var = @by_ref[ref].as(TypeVariable)

      explicit = AST::Extract.param(node.lhs)[1]
      @bindings << {explicit.pos, var, @by_node[explicit]} if explicit

      rhs = @by_node[node.rhs].stabilized
      @assignments << {node.pos, var, rhs}

      @by_node[node] = var.aliased
    end
  end

  class Visitor < AST::Visitor
    getter analysis
    private getter refer_type : ReferType::Analysis
    private getter! classify : Classify::Analysis
    private getter! refer : Refer::Analysis
    private getter! local : Local::Analysis

    def initialize(
      @analysis : Analysis,
      @refer_type,
      @classify = nil,
      @refer = nil,
      @local = nil,
    )
    end

    def run_for_type_alias(ctx : Context, t : Program::TypeAlias)
      # TODO: Allow running this pass for more than just the root library.
      # We restrict this for now while we are building out the pass because
      # we don't want to deal with all of the complicated forms in the prelude.
      # We want to stick to the simple forms in the compiler pass specs for now.
      root_library = ctx.namespace.root_library(ctx).source_library
      return unless t.ident.pos.source.library == root_library

      raise NotImplementedError.new("run_for_type_alias")
    end

    def run_for_type(ctx : Context, t : Program::Type)
      # TODO: Allow running this pass for more than just the root library.
      # We restrict this for now while we are building out the pass because
      # we don't want to deal with all of the complicated forms in the prelude.
      # We want to stick to the simple forms in the compiler pass specs for now.
      root_library = ctx.namespace.root_library(ctx).source_library
      return unless t.ident.pos.source.library == root_library

      @analysis.init_type_self(
        t.params.try(&.terms.map { |param|
          ident, explicit, default = AST::Extract.type_param(param)
          {
            param,
            explicit ? read_type_expr(ctx, explicit) : nil,
            default ? read_type_expr(ctx, default) : nil,
          }
        })
      )
    end

    def run_for_function(ctx : Context, f : Program::Function)
      # TODO: Allow running this pass for more than just the root library.
      # We restrict this for now while we are building out the pass because
      # we don't want to deal with all of the complicated forms in the prelude.
      # We want to stick to the simple forms in the compiler pass specs for now.
      root_library = ctx.namespace.root_library(ctx).source_library
      return unless f.ident.pos.source.library == root_library

      @analysis.init_func_self(f.cap.value, f.cap.pos)

      f.params.try(&.accept(ctx, self))
      f.body.try(&.accept(ctx, self))
    end

    def visit_any?(ctx, node)
      # Read type expressions using a different, top-down kind of approach.
      # This prevents the normal depth-first visit when false is returned.
      if !@classify || classify.type_expr?(node)
        @analysis[node] = read_type_expr(ctx, node)
        false
      else
        true
      end
    end

    def read_type_expr(ctx, node : AST::Identifier)
      ref = @refer_type[node]

      case ref
      when Refer::Type
        t = ref.link.resolve(ctx)
        NominalType.new(ref.link).intersect(NominalCap.new(t.cap.value))
      else
        raise NotImplementedError.new(ref.class)
      end
    end

    def read_type_expr(ctx, node : AST::Qualify)
      raise NotImplementedError.new(node.to_a) unless node.group.style == "("

      args = node.group.terms.map { |arg| read_type_expr(ctx, arg) }
      term = Intersection.new(
        read_type_expr(node.term).as(Intersection).members.map { |member|
          next member unless member.is_a?(NominalType)

          NominalType.new(member.link, args)
        }
      )

      case ref
      when Refer::Type
        t = ref.link.resolve(ctx)
        NominalType.new(ref.link).intersect(NominalCap.new(t.cap.value))
      else
        raise NotImplementedError.new(ref.class)
      end
    end

    def read_type_expr(ctx, node)
      raise NotImplementedError.new(node.class)
    end

    def visit(ctx, node : AST::Identifier)
      return if classify.no_value?(node)

      ref = (@refer || @refer_type)[node]
      case ref
      when Refer::Self
        @analysis.observe_self_reference(node, ref)
      when Refer::Local
        @analysis.observe_local_reference(node, ref)
      when Refer::Type
        if ref.with_value
          # We allow it to be resolved as if it were a type expression,
          # since this enum value literal will have the type of its referent.
          t = ref.link.resolve(ctx)
          @analysis[node] = NominalType.new(ref.link).intersect(
            NominalCap.new(t.cap.value)
          )
        else
          # A type reference whose value is used and is not itself a value
          # must be marked non, rather than having the default cap for that type.
          # This is used when we pass a type around as if it were a value,
          # where that value is a stateless singleton able to call `:fun non`s.
          @analysis[node] = NominalType.new(ref.link).intersect(
            NominalCap.new("non")
          )
        end
      else
        raise NotImplementedError.new(ref.class)
      end
    end

    def visit(ctx, node : AST::Operator)
      # Do nothing.
    end

    def visit(ctx, node : AST::LiteralString)
      case node.prefix_ident.try(&.value)
      when nil then @analysis.observe_prelude_type(ctx, node, "String", "val")
      when "b" then @analysis.observe_prelude_type(ctx, node, "Bytes", "val")
      else
        ctx.error_at node.prefix_ident.not_nil!,
          "This type of string literal is not known; please remove this prefix"
        @analysis.observe_prelude_type(ctx, node, "String", "val")
      end
    end

    def visit(ctx, node : AST::Group)
      return if classify.value_not_needed?(node)

      case node.style
      when "|"
        # Do nothing here - we'll handle it in one of the parent nodes.
      when "(", ":"
        if node.terms.empty?
          @analysis.observe_prelude_type(ctx, node, "None", "non")
        else
          @analysis.observe_transitive(node, node.terms.last)
        end
      else raise NotImplementedError.new(node.style)
      end
    end

    def visit(ctx, node : AST::Relate)
      case node.op.value
      when "EXPLICITTYPE"
        # Assign the type variable from the left hand side to this node.
        @analysis[node] = @analysis[node.lhs]
      when "="
        ident = AST::Extract.param(node.lhs).first
        ref = refer[ident].as(Refer::Local)
        @analysis.observe_assignment(node, ref)
      else
        raise NotImplementedError.new(node.op.value)
      end
    end

    def visit(ctx, node : AST::Choice)
      node.list.each { |cond, body|
        @analysis.observe_assert_bool(ctx, cond)
      }
      @analysis[node] =
        Union.from(node.list.map { |cond, body| @analysis[body] })
    end

    def visit(ctx, node)
      raise NotImplementedError.new(node.class)
    end
  end

  class Pass < Compiler::Pass::Analyze(Analysis, Analysis, Analysis)
    def analyze_type_alias(ctx, t, t_link) : Analysis
      refer_type = ctx.refer_type[t_link]
      deps = {refer_type}
      prev = ctx.prev_ctx.try(&.types)

      maybe_from_type_alias_cache(ctx, prev, t, t_link, deps) do
        Visitor.new(Analysis.new(t_link), *deps)
          .tap(&.run_for_type_alias(ctx, t))
          .analysis
      end
    end

    def analyze_type(ctx, t, t_link) : Analysis
      refer_type = ctx.refer_type[t_link]
      deps = {refer_type}
      prev = ctx.prev_ctx.try(&.types)

      maybe_from_type_cache(ctx, prev, t, t_link, deps) do
        Visitor.new(Analysis.new(t_link), *deps)
          .tap(&.run_for_type(ctx, t))
          .analysis
      end
    end

    def analyze_func(ctx, f, f_link, t_analysis) : Analysis
      refer_type = ctx.refer_type[f_link]
      classify = ctx.classify[f_link]
      refer = ctx.refer[f_link]
      local = ctx.local[f_link]
      deps = {refer_type, classify, refer, local}
      prev = ctx.prev_ctx.try(&.types)

      maybe_from_func_cache(ctx, prev, f, f_link, deps) do
        Visitor.new(Analysis.new(f_link, t_analysis), *deps)
          .tap(&.run_for_function(ctx, f))
          .analysis
      end
    end
  end
end
