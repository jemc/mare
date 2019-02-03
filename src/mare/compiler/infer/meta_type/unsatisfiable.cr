class Mare::Compiler::Infer::MetaType::Unsatisfiable
  INSTANCE = new
  
  def self.instance
    INSTANCE
  end
  
  private def self.new
    super
  end
  
  def inspect(io : IO)
    io << "<unsatisfiable>"
  end
  
  def hash : UInt64
    self.class.hash
  end
  
  def ==(other)
    other.is_a?(Unsatisfiable)
  end
  
  def each_reachable_defn : Iterator(Program::Type)
    ([] of Program::Type).each
  end
  
  def find_callable_func_defns(name : String)
    nil
  end
  
  def negate : Inner
    # The negation of an Unsatisfiable is... well... I'm not sure yet.
    # Is it Unconstrained?
    raise NotImplementedError.new("negation of #{inspect}")
  end
  
  def intersect(other : Inner)
    # The intersection of Unsatisfiable and anything is still Unsatisfiable.
    self
  end
  
  def unite(other : Inner)
    # The union of Unsatisfiable and anything is the other thing.
    other
  end
  
  def subtype_of?(other : Inner) : Bool
    # Unsatisfiable is a subtype of nothing - it cannot exist at all.
    # TODO: is this right? it seems so, but breaks symmetry with Unconstrained.
    false
  end
  
  def supertype_of?(other : Inner) : Bool
    # Unsatisfiable is never a supertype - it is never satisfied.
    false
  end
end