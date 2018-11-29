require "./spec_helper"

describe Mare::Parser do
  it "parses an example" do
    source = fixture "example.mare"
    
    ast = Mare::Parser.parse(source)
    ast.should be_truthy
    next unless ast
    
    ast.to_a.should eq [:doc,
      [:declare, [[:ident, "class"], [:ident, "Example"]], [:group, ":"]],
      [:declare,
        [[:ident, "prop"], [:ident, "name"], [:ident, "String"]],
        [:group, ":", [:string, "World"]]
      ],
      [:declare,
        [[:ident, "fun"], [:ident, "greeting"], [:ident, "String"]],
        [:group, ":", [:relate,
          [:relate,
            [:string, "Hello, "],
            [:op, "+"],
            [:prefix, [:op, "@"], [:ident, "name"]],
          ],
          [:op, "+"],
          [:string, "!"],
        ]]
      ],
      [:declare,
        [
          [:ident, "fun"],
          [:ident, "degreesF"],
          [:group, "(", [:relate, [:ident, "c"], [:op, " "], [:ident, "F64"]]],
          [:ident, "F64"]
        ],
        [:group, ":", [:relate,
          [:relate,
            [:relate, [:ident, "c"], [:op, "*"], [:integer, 9]],
            [:op, "/"],
            [:integer, 5],
          ],
          [:op, "+"], [:float, 32.0],
        ]]
      ],
      [:declare,
        [[:ident, "fun"], [:ident, "caller"]],
        [:group, ":", [:qualify,
          [:prefix, [:op, "@"], [:ident, "degreesF"]],
          [:group, "(",
            [:relate,
              [:relate, [:integer, 10], [:op, "."], [:qualify,
                [:ident, "add"],
                [:group, "(", [:integer, 2]],
              ]],
              [:op, "."],
              [:qualify,
                [:ident, "sub"],
                [:group, "(", [:integer, 1]],
              ],
            ],
          ],
        ]]
      ],
    ]
  end
  
  it "parses operators" do
    source = fixture "operators.mare"
    
    ast = Mare::Parser.parse(source)
    ast.should be_truthy
    next unless ast
    
    # Can't use array literals here because Crystal is too slow to compile them.
    # See https://github.com/crystal-lang/crystal/issues/5792
    ast.to_a.pretty_inspect(74).should eq <<-AST
    [:doc,
     [:declare, [[:ident, "describe"], [:ident, "operators"]], [:group, ":"]],
     [:declare,
      [[:ident, "demo"], [:ident, "all"]],
      [:group,
       ":",
       [:relate,
        [:ident, "x"],
        [:op, " "],
        [:relate,
         [:relate, [:ident, "x"], [:op, "&&"], [:ident, "x"]],
         [:op, "||"],
         [:relate,
          [:relate,
           [:relate,
            [:relate,
             [:relate, [:ident, "x"], [:op, "==="], [:ident, "x"]],
             [:op, "=="],
             [:ident, "x"]],
            [:op, "!=="],
            [:ident, "x"]],
           [:op, "!="],
           [:ident, "x"]],
          [:op, "=~"],
          [:relate,
           [:relate,
            [:relate,
             [:relate, [:ident, "x"], [:op, ">="], [:ident, "x"]],
             [:op, "<="],
             [:ident, "x"]],
            [:op, "<"],
            [:ident, "x"]],
           [:op, ">"],
           [:relate,
            [:relate,
             [:relate,
              [:relate,
               [:relate,
                [:relate,
                 [:relate,
                  [:relate,
                   [:relate,
                    [:relate, [:ident, "x"], [:op, "<|>"], [:ident, "x"]],
                    [:op, "<~>"],
                    [:ident, "x"]],
                   [:op, "<<<"],
                   [:ident, "x"]],
                  [:op, ">>>"],
                  [:ident, "x"]],
                 [:op, "<<~"],
                 [:ident, "x"]],
                [:op, "~>>"],
                [:ident, "x"]],
               [:op, "<<"],
               [:ident, "x"]],
              [:op, ">>"],
              [:ident, "x"]],
             [:op, "<~"],
             [:ident, "x"]],
            [:op, "~>"],
            [:relate,
             [:relate, [:ident, "x"], [:op, ".."], [:ident, "x"]],
             [:op, "<>"],
             [:relate,
              [:relate, [:ident, "x"], [:op, "+"], [:ident, "x"]],
              [:op, "-"],
              [:relate,
               [:relate, [:ident, "x"], [:op, "*"], [:ident, "x"]],
               [:op, "/"],
               [:ident, "x"]]]]]]]]]]],
     [:declare,
      [[:ident, "demo"], [:ident, "mixed"]],
      [:group,
       ":",
       [:relate,
        [:relate,
         [:relate, [:ident, "a"], [:op, "!="], [:ident, "b"]],
         [:op, "&&"],
         [:relate,
          [:ident, "c"],
          [:op, ">"],
          [:relate,
           [:relate, [:ident, "d"], [:op, "/"], [:ident, "x"]],
           [:op, "+"],
           [:relate, [:ident, "e"], [:op, "/"], [:ident, "y"]]]]],
        [:op, "||"],
        [:relate,
         [:relate, [:ident, "i"], [:op, ".."], [:ident, "j"]],
         [:op, ">"],
         [:relate, [:ident, "k"], [:op, "<<"], [:ident, "l"]]]]]]]
    AST
  end
end
