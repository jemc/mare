struct Mare::Compiler::Infer::MetaType::Nominal
  getter defn : ReifiedType | ReifiedTypeAlias | TypeParam

  def initialize(@defn)
  end

  def inspect(io : IO)
    inspect_without_cap(io)

    io << "'any" unless defn.is_a?(ReifiedTypeAlias)
  end

  def inspect_with_cap(io : IO, cap : Capability)
    inspect_without_cap(io)

    # If the cap is the same as the default cap, we omit it for brevity.
    # Otherwise, we'll print it here with the same syntax that the programmer
    # can use to specify it explicitly.
    defn = defn()
    unless defn.is_a?(ReifiedType) && cap.value == defn.link.cap
      io << "'"
      cap.inspect(io)
    end
  end

  def inspect_without_cap(io : IO)
    defn = defn()
    case defn
    when ReifiedType, ReifiedTypeAlias
      defn.show_type(io)
    when TypeParam
      parent_rt = defn.parent_rt
      if parent_rt
        io << "["
        io << defn.ref.ident.value
        io << " from "
        io << defn.parent_rt.try(&.show_type)
        io << "]"
      else
        io << defn.ref.ident.value
      end
    end
  end

  def each_reachable_defn(ctx : Context) : Iterator(ReifiedType)
    defn = defn()
    case defn
    when TypeParam
      ([] of ReifiedType).each
    when ReifiedType
      [defn].each
    when ReifiedTypeAlias
      MetaType.simplify_inner(ctx, self).each_reachable_defn(ctx)
    else
      raise NotImplementedError.new(defn)
    end
  end

  def find_callable_func_defns(ctx, infer : ForReifiedFunc, name : String)
    raise NotImplementedError.new("simplify first to remove aliases") if defn.is_a?(ReifiedTypeAlias)

    defn = defn()
    case defn
    when ReifiedType
      func = defn.defn(ctx).find_func?(name)
      [{self, defn, func}] if func
    when TypeParam
      infer.lookup_type_param_bound(defn)
        .find_callable_func_defns(ctx, infer, name)
    else
      raise NotImplementedError.new(defn)
    end
  end

  def any_callable_func_defn_type(ctx, name : String) : ReifiedType?
    raise NotImplementedError.new("simplify first to remove aliases") if defn.is_a?(ReifiedTypeAlias)

    defn = defn()
    if defn.is_a?(ReifiedType)
      func = defn.defn(ctx).find_func?(name)
      defn if func
    end
  end

  def is_concrete?
    raise NotImplementedError.new("simplify first to remove aliases") if defn.is_a?(ReifiedTypeAlias)

    defn = defn()
    defn.is_a?(ReifiedType) && defn.link.is_concrete?
  end

  def is_non_alias_and_concrete?
    return false if defn.is_a?(ReifiedTypeAlias)
    is_concrete?
  end

  def negate : Inner
    AntiNominal.new(defn)
  end

  def intersect(other : Unconstrained)
    self
  end

  def intersect(other : Unsatisfiable)
    other
  end

  def intersect(other : Capability)
    Intersection.new(other, [self].to_set)
  end

  def intersect(other : Nominal)
    raise NotImplementedError.new("simplify first to remove aliases") if defn.is_a?(ReifiedTypeAlias)

    # No change if the two nominal types are identical.
    return self if defn == other.defn

    # Unsatisfiable if the two are concrete types that are not identical.
    return Unsatisfiable.instance \
      if is_non_alias_and_concrete? && other.is_non_alias_and_concrete?

    # Otherwise, this is a new intersection of the two types.
    Intersection.new(nil, [self, other].to_set)
  end

  def intersect(other : (AntiNominal | Intersection | Union))
    other.intersect(self) # delegate to the "higher" class via commutativity
  end

  def unite(other : Unconstrained)
    other
  end

  def unite(other : Unsatisfiable)
    self
  end

  def unite(other : Capability)
    Union.new([other].to_set, [self].to_set)
  end

  def unite(other : Nominal)
    # No change if the two nominal types are identical.
    return self if defn == other.defn

    # Otherwise, this is a new union of the two types.
    Union.new(nil, [self, other].to_set)
  end

  def unite(other : (AntiNominal | Intersection | Union))
    other.unite(self) # delegate to the "higher" class via commutativity
  end

  def ephemeralize
    raise NotImplementedError.new("simplify first to remove aliases") if defn.is_a?(ReifiedTypeAlias)

    self # no effect
  end

  def strip_ephemeral
    raise NotImplementedError.new("simplify first to remove aliases") if defn.is_a?(ReifiedTypeAlias)

    self # no effect
  end

  def alias
    raise NotImplementedError.new("simplify first to remove aliases") if defn.is_a?(ReifiedTypeAlias)

    self # no effect
  end

  def strip_cap
    raise NotImplementedError.new("simplify first to remove aliases") if defn.is_a?(ReifiedTypeAlias)

    self # no effect
  end

  def partial_reifications
    raise NotImplementedError.new("simplify first to remove aliases") if defn.is_a?(ReifiedTypeAlias)

    # Intersect with every possible non-ephemeral cap.
    Capability::ALL_NON_EPH.map(&.intersect(self)).to_set
  end

  def type_params
    defn = defn()
    case defn
    when TypeParam
      [defn].to_set
    when ReifiedType
      defn.args.flat_map(&.type_params.as(Set(TypeParam)).to_a).to_set
    when ReifiedTypeAlias
      defn.args.flat_map(&.type_params.as(Set(TypeParam)).to_a).to_set
    else
      raise NotImplementedError.new(defn)
    end
  end

  def substitute_type_params(substitutions : Hash(TypeParam, MetaType))
    defn = defn()
    case defn
    when TypeParam
      substitutions[defn]?.try(&.inner) || self
    when ReifiedType
      args = defn.args.map do |arg|
        arg.substitute_type_params(substitutions).as(MetaType)
      end

      Nominal.new(ReifiedType.new(defn.link, args))
    when ReifiedTypeAlias
      args = defn.args.map do |arg|
        arg.substitute_type_params(substitutions).as(MetaType)
      end

      Nominal.new(ReifiedTypeAlias.new(defn.link, args))
    else
      raise NotImplementedError.new(defn)
    end
  end

  def is_sendable?
    raise NotImplementedError.new("simplify first to remove aliases") if defn.is_a?(ReifiedTypeAlias)

    # An nominal is never itself sendable -
    # it specifies a single nominal, and says nothing about capabilities.
    false
  end

  def safe_to_match_as?(ctx : Context, other) : Bool?
    raise NotImplementedError.new("simplify first to remove aliases") if defn.is_a?(ReifiedTypeAlias)

    supertype_of?(ctx, other) ? true : nil
  end

  def viewed_from(origin)
    raise NotImplementedError.new("simplify first to remove aliases") if defn.is_a?(ReifiedTypeAlias)

    raise NotImplementedError.new("#{origin.inspect}->#{self.inspect}")
  end

  def extracted_from(origin)
    raise NotImplementedError.new("simplify first to remove aliases") if defn.is_a?(ReifiedTypeAlias)

    raise NotImplementedError.new("#{origin.inspect}->>#{self.inspect}")
  end

  def subtype_of?(ctx : Context, other : Capability) : Bool
    raise NotImplementedError.new("simplify first to remove aliases") if defn.is_a?(ReifiedTypeAlias)

    # A nominal can never be a subtype of any capability -
    # it specifies a single nominal, and says nothing about capabilities.
    false
  end

  def supertype_of?(ctx : Context, other : Capability) : Bool
    raise NotImplementedError.new("simplify first to remove aliases") if defn.is_a?(ReifiedTypeAlias)

    # A nominal can never be a supertype of any capability -
    # it specifies a single nominal, and says nothing about capabilities.
    false
  end

  def subtype_of?(ctx : Context, other : Nominal) : Bool
    raise NotImplementedError.new("simplify first to remove aliases") if defn.is_a?(ReifiedTypeAlias)
    raise NotImplementedError.new("simplify first to remove aliases") if other.defn.is_a?(ReifiedTypeAlias)

    defn = defn()
    other_defn = other.defn()
    errors = [] of Error::Info # TODO: accept this as an argument?

    if defn.is_a?(ReifiedType)
      if other_defn.is_a?(ReifiedType)
        # When both sides are ReifiedTypes, delegate to the SubtypingInfo logic.
        ctx.infer[other_defn].is_supertype_of?(ctx, defn, errors)
      elsif other_defn.is_a?(TypeParam)
        # When the other is a TypeParam, use its bound MetaType and run again.
        l = MetaType.new_nominal(defn)
        other_parent_link = other_defn.ref.parent_link
        if other_parent_link.is_a?(Program::Type::Link)
          r = ctx.infer.for_rt(ctx, other_parent_link)
                .lookup_type_param_bound(other_defn).strip_cap
        elsif other_parent_link.is_a?(Program::TypeAlias::Link)
          raise NotImplementedError.new("lookup_type_param_bound for TypeAlias")
        else
          raise NotImplementedError.new(other_parent_link)
        end
        l.subtype_of?(ctx, r.not_nil!)
      else
        raise NotImplementedError.new("type <: ?")
      end
    elsif defn.is_a?(TypeParam)
      if other_defn.is_a?(ReifiedType)
        # When this is a TypeParam, use its bound MetaType and run again.
        l = ctx.infer.for_rt(ctx, defn.ref.parent_link.as(Program::Type::Link))
              .lookup_type_param_bound(defn).strip_cap
        r = MetaType.new_nominal(other_defn)
        l.subtype_of?(ctx, r)
      elsif other_defn.is_a?(TypeParam)
        if defn.ref == other_defn.ref
          return true if defn.parent_rt == other_defn.parent_rt
          return true if defn.parent_rt.nil?
          return true if other_defn.parent_rt.nil?
        end
        raise NotImplementedError.new("type param <: type param")
      else
        raise NotImplementedError.new("type param <: ?")
      end
    else
      raise NotImplementedError.new("? <: anything")
    end
  end

  def supertype_of?(ctx : Context, other : Nominal) : Bool
    other.subtype_of?(ctx, self) # delegate to the method above via symmetry
  end

  def subtype_of?(ctx : Context, other : (AntiNominal | Intersection | Union | Unconstrained | Unsatisfiable)) : Bool
    other.supertype_of?(ctx, self) # delegate to the other class via symmetry
  end

  def supertype_of?(ctx : Context, other : (AntiNominal | Intersection | Union | Unconstrained | Unsatisfiable)) : Bool
    other.subtype_of?(ctx, self) # delegate to the other class via symmetry
  end

  def satisfies_bound?(ctx : Context, bound : Nominal) : Bool
    subtype_of?(ctx, bound)
  end

  def satisfies_bound?(ctx : Context, bound : (Capability | AntiNominal | Intersection | Union | Unconstrained | Unsatisfiable)) : Bool
    raise NotImplementedError.new("#{self} satisfies_bound? #{bound}")
  end
end
