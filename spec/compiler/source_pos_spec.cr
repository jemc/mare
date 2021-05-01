describe Mare::Source::Pos do
  it "builds from a source and offset" do
    source = Mare::Source.new_example <<-SOURCE
    :class Foo
      :prop a A
      :new (@a)
      :fun string String
        if (A <: String) (@a | "...")

    SOURCE
    
    # Point to the F character on line 1
    pos = Mare::Source::Pos.point(source, 7)

    pos.start.should eq(7)
    pos.finish.should eq(7)
    pos.line_start.should eq(0)
    pos.line_finish.should eq(10)
    pos.row.should eq(0)
    pos.col.should eq(7)

    # Point to the @ character on line 3
    pos = Mare::Source::Pos.point(source, 31)

    pos.start.should eq(31)
    pos.finish.should eq(31)
    pos.line_start.should eq(23)
    pos.line_finish.should eq(34)
    pos.row.should eq(2)
    pos.col.should eq(8)
  end
end
