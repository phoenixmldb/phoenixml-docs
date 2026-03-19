---
title: Boolean Functions
description: XPath boolean construction and logic functions
sort: 5
---

# Boolean Functions

XPath has just four boolean functions. Booleans work differently than in C# in one key way: XPath has "effective boolean value" rules that automatically convert other types to boolean in conditional contexts.

---

### boolean()

Converts a value to boolean using XPath's effective boolean value rules.

**Signature:** `boolean($value as item()*) as xs:boolean`

```xpath
boolean("hello")    => true     (: non-empty string :)
boolean("")         => false    (: empty string :)
boolean(42)         => true     (: non-zero number :)
boolean(0)          => false    (: zero :)
boolean(())         => false    (: empty sequence :)
boolean((1, 2))     => true     (: non-empty sequence starting with a node or value :)
```

**Effective boolean value rules:**
| Input | Result |
|-------|--------|
| Empty sequence `()` | `false` |
| Sequence starting with a node | `true` |
| Single `xs:boolean` | Its value |
| Single `xs:string` | `true` if non-empty |
| Single number | `true` if non-zero and not NaN |

**C# equivalent:** There's no single C# equivalent — C# doesn't implicitly convert strings or numbers to booleans.

**Why this matters:** In XPath, you can write `if (//error) then ...` and it works — the sequence of error nodes is automatically converted to `true` if any exist. You don't need `if (count(//error) > 0)`.

---

### true()

Returns `true`. Needed because XPath doesn't have boolean literals.

**Signature:** `true() as xs:boolean`

```xpath
true()   => true
```

**Note:** Unlike C#'s `true`, this is a function call with parentheses. XPath 4.0 also allows the keyword `true` without parentheses in some contexts.

---

### false()

Returns `false`.

**Signature:** `false() as xs:boolean`

```xpath
false()   => false
```

---

### not()

Logical negation.

**Signature:** `not($value as item()*) as xs:boolean`

```xpath
not(true())               => false
not(false())              => true
not(())                   => true    (: empty sequence is "falsy" :)
not(//error)              => true if no error elements exist
not(contains("abc", "x")) => true
```

**C# equivalent:** `!value`

**Common pattern:**
```xpath
//book[not(@out-of-print)]          (: books without the out-of-print attribute :)
//item[not(price > 100)]            (: items not over $100 :)
```
