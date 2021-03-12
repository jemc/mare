describe Mare::Compiler::Reach do
  it "reaches compatible functions when reaching a trait function" do
    source = Mare::Source.new_example <<-SOURCE
    :trait Trait
      :fun foo U64

    :class Class
      :fun foo U64: 0

    :class Other
      :fun foo F64: 0 // the return type in the function signature doesn't match

    :actor Main
      :new
        o = Other.new
        i Trait = Class.new
        i.foo
    SOURCE

    ctx = Mare.compiler.compile([source], :reach)

    i_foo = ctx.type_check.for_func_simple(ctx, source, "Trait", "foo").reified
    c_foo = ctx.type_check.for_func_simple(ctx, source, "Class", "foo").reified
    o_foo = ctx.type_check.for_func_simple(ctx, source, "Other", "foo").reified

    ctx.reach.reached_func?(i_foo).should eq true
    ctx.reach.reached_func?(c_foo).should eq true
    ctx.reach.reached_func?(o_foo).should eq false
  end
end
