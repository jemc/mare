---
pass: types
---

It analyzes a simple system of types.

```mare
:primitive Example1(A MapReadable(String, String))
  :fun example(cond Bool)
    x String = "value"
    y = if cond ("string" | b"bytes")
```
```types.type_variables_list Example1.example
T'@'1
  := (Example1 & K'@'2)
    :fun example
     ^~~

T'x'3
  := (String & val)
      x String = "value"
        ^~~~~~
  |= (String & val)
      x String = "value"
      ^~~~~~~~~~~~~~~~~~

T'y'4
  |= ((String & val) | (Bytes & val))
      y = if True ("string" | b"bytes")
      ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  (Bool & val) :> (Bool & val)
      y = if True ("string" | b"bytes")
             ^~~~
  (Bool & val) :> (Bool & val)
      y = if True ("string" | b"bytes")
          ^~
```
