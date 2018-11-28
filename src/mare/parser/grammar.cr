require "pegmatite"

module Mare::Parser
  Grammar = Pegmatite::DSL.define do
    # Define what whitespace looks like.
    whitespace =
      char(' ') | char('\t') | char('\r') | str("\\\n") | str("\\\r\n")
    s = whitespace.repeat
    sn = (whitespace | char('\n')).repeat
    
    # Define what an identifier looks like.
    ident_letter =
      range('a', 'z') | range('A', 'Z') | range('0', '9') | char('_')
    ident = ident_letter.repeat(1).named(:ident)
    
    # Define what a number looks like (integer and float).
    digit19 = range('1', '9')
    digit = range('0', '9')
    digits = digit.repeat(1)
    int =
      (char('-') >> digit19 >> digits) |
      (char('-') >> digit) |
      (digit19 >> digits) |
      digit
    frac = char('.') >> digits
    exp = (char('e') | char('E')) >> (char('+') | char('-')).maybe >> digits
    integer = int.named(:integer)
    float = (int >> ((frac >> exp.maybe) | exp)).named(:float)
    
    # Define what a string looks like.
    hex = digit | range('a', 'f') | range('A', 'F')
    string_char =
      str("\\\"") | str("\\\\") | str("\\|") |
      str("\\b") | str("\\f") | str("\\n") | str("\\r") | str("\\t") |
      (str("\\u") >> hex >> hex >> hex >> hex) |
      (~char('"') >> ~char('\\') >> range(' ', 0x10FFFF_u32))
    string = char('"') >> string_char.repeat.named(:string) >> char('"')
    
    # Define an atom to be a single term with no binary operators.
    parens = declare
    prefixed = declare
    atom = prefixed | parens | string | float | integer | ident
    
    # Define a prefixed term to be preceded by a prefix operator.
    prefixop = char('@').named(:op)
    prefixed.define (prefixop >> atom).named(:prefix)
    
    # Define a qualified term to be followed by a parenthesized group.
    qualify = (atom >> s >> parens).named(:qualify)
    suffixed = qualify
    
    # Define groups of operators, in order of precedence,
    # from most tightly binding to most loosely binding.
    # Operators in the same group have the same level of precedence.
    op1 = (char('.')).named(:op)
    op2 = (char('*') | char('/')).named(:op)
    op3 = (char('+') | char('-')).named(:op)
    op4 = (str("..") | str("<>")).named(:op)
    op5 = (str("<|>") | str("<~>") | str("<<<") | str(">>>") |
            str("<<~") | str("~>>") | str("<<") | str(">>") |
            str("<~") | str("~>")).named(:op)
    op6 = ((str(">=") | str("<=") | char('<') | char('>')) >>
            ~(char('>') | char('<') | char('~') | char('|'))).named(:op)
    op7 = (str("===") | str("==") | str("!==") | str("!=") |
            str("=~")).named(:op)
    op8 = (str("&&") | str("||")).named(:op)
    opw = (char(' ') | char('\t')).named(:op)
    
    # Construct the nested possible relations for each group of operators.
    # TODO: Simplify this construction without reducing performance.
    t1 = suffixed | atom
    t2 = t1 >> ~(sn >> op1) | (t1 >> (sn >> op1 >> sn >> t1 >> s).repeat(1)).named(:relate) | t1
    t3 = t2 >> ~(sn >> op2) | (t2 >> (sn >> op2 >> sn >> t2 >> s).repeat(1)).named(:relate) | t2
    t4 = t3 >> ~(sn >> op3) | (t3 >> (sn >> op3 >> sn >> t3 >> s).repeat(1)).named(:relate) | t3
    t5 = t4 >> ~(sn >> op4) | (t4 >> (sn >> op4 >> sn >> t4 >> s).repeat(1)).named(:relate) | t4
    t6 = t5 >> ~(sn >> op5) | (t5 >> (sn >> op5 >> sn >> t5 >> s).repeat(1)).named(:relate) | t5
    t7 = t6 >> ~(sn >> op6) | (t6 >> (sn >> op6 >> sn >> t6 >> s).repeat(1)).named(:relate) | t6
    t8 = t7 >> ~(sn >> op7) | (t7 >> (sn >> op7 >> sn >> t7 >> s).repeat(1)).named(:relate) | t7
    tw = t8 >> ~(sn >> op8) | (t8 >> (sn >> op8 >> sn >> t8 >> s).repeat(1)).named(:relate) | t8
    t = (tw >> (opw >> tw >> s).repeat(1)).named(:relate) | tw
    
    # Define groups that are comma-separated lists of terms.
    terms = t >> s >> (char(',') >> sn >> t >> s).repeat
    parens.define (char('(') >> s >> terms >> s >> char(')')).named(:group)
    
    # Define what a declaration head of terms looks like.
    dterm = atom
    dterms = dterm >> (s >> dterm).repeat >> s
    decl = (dterms >> s >> char(':') >> s).named(:decl)
    
    # Define what an end-of-line comment looks like.
    eol_comment = str("//") >> (~char('\n') >> any).repeat
    eol_item = eol_comment
    
    # Define what a line looks like.
    line_item = (decl >> terms.maybe) | terms
    line =
      s >>
      (s >> ~eol_item >> line_item).repeat >>
      (s >> eol_item.maybe) >>
      s
    
    # Define a total document to be a sequence of lines.
    doc = ((line >> char('\n')).repeat >> line >> sn).named(:doc)
    
    # A valid parse is a single document followed by the end of the file.
    doc.then_eof
  end
end