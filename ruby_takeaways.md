# Ruby Takeaways

Things that weren't clear at first, figured out together while working through the exercises.

## `attr_reader` / `attr_writer` / `attr_accessor`

Instance variables (`@items`) are private to the object — nothing outside can read `@items` directly, and there's no dot-syntax for it. To expose one, you'd normally write a getter method yourself:

```ruby
def items
  @items
end
```

`attr_reader :items` generates exactly that method for you — one line instead of three. That's why a method elsewhere in the same class can call `items` (no `@`) and get the instance variable's value back: it's calling a generated method, not touching the ivar.

- `attr_writer :items` generates the setter (`def items=(value); @items = value; end`)
- `attr_accessor :items` generates both reader and writer

Found while working on: `boutique-inventory-improvements` — `items` (via `attr_reader`) vs `@items` direct access in `total_stock` / `item_names`.

## `&:symbol` only works for a single method call

`&:name` is shorthand for `{ |item| item.name }` — it calls **exactly one** method, with no arguments, on each element. It does NOT chain: `item.quantity_by_size.values` is *two* method calls per element, so it can't be written as a single `&:something`.

Options once you need more than one call per element:
- Write a real block: `items.sum { |item| item.quantity_by_size.values.sum }`
- Or chain separate `&:` maps, one per call: `items.map(&:quantity_by_size).map(&:values)`

Also clarified: `sum` with a block computes an expression per element and adds the results (needed when you're deriving a value, like `.values.sum` per item) — that's different from `map(&:name)`, which just pulls a raw attribute per element. If you're only fetching an attribute, `&:` + `map` is enough; if you're computing something per element before combining, you need a block.

Found while working on: `boutique-inventory-improvements` — `total_stock`, trying to avoid a `do |item| ... end` block via `&:quantity_by_size`.

## `**` spreads a hash into a new hash literal, not just into method calls

`**` (double splat) is usually introduced as a way to unpack keyword arguments into a method call (`some_method(**options)`). But it works the same way inside a plain `{ }` hash literal: `{ **existing_hash, new_key: value }` copies every key/value pair from `existing_hash` into the new hash, then adds `new_key` alongside them. It reads like spreading an array with `[first, second, *rest]`, just for hashes instead of arrays.

This matters because it's the non-mutating way to "add a key to a hash": instead of `hash[:new_key] = value` (which mutates the object you were passed, a surprising side effect for a method that isn't named with a `!`), you can return a brand-new hash built from the old one plus the addition, leaving the original untouched.

```ruby
route = { from: "Berlin", to: "Hamburg" }
{ **route, stops: ["Leipzig"] }
# => { from: "Berlin", to: "Hamburg", stops: ["Leipzig"] }
```

Found while working on: `locomotive-engineer` — `add_missing_stops`, avoiding `route[:stops] = ...` mutating the argument in place.

## `*` vs `**` in a method signature: match the splat to what the caller is actually sending

`*args` collects **positional** arguments into an Array. `**kwargs` collects **keyword** arguments (`key: value` pairs) into a Hash. Both can be technically legal for the same call site, which hides the mistake: if a method only has `*stops` and you call it with `stop_1: "a", stop_2: "b"`, Ruby doesn't error — it falls back to treating the trailing keyword pairs as a single implicit positional Hash argument, so `*stops` ends up as `[{stop_1: "a", stop_2: "b"}]` (an array containing one hash), not the flat list you'd expect.

That extra layer of wrapping then forces awkward workarounds downstream (e.g. needing `flat_map(&:values)` to dig the values out through the array-then-hash nesting) that wouldn't be necessary at all with the right splat:

```ruby
def add_missing_stops(route, **stops)
  { **route, stops: stops.values }
end
```

With `**stops`, Ruby collects the keyword arguments directly into a Hash — no wrapping array — so `.values` alone gives the flat list. The lesson: when a call site passes `key: value` pairs, reach for `**`, not `*` — don't let "it happens to run" stand in for "it's the right parameter type." If you find yourself flattening or unwrapping an extra layer right after collecting args, that's a signal the splat type doesn't match what's actually being passed in.

Found while working on: `locomotive-engineer` — `add_missing_stops`; originally written with `*stops` + `flat_map(&:values)`, simplified to `**stops` + `.values` after comparing with community solutions.

## `def self.foo` vs `def foo` inside a class — attaches to the class or to instances

`def foo` inside a class body defines an **instance** method — it only exists on objects created via `SomeClass.new`, and needs one in hand to call (`obj.foo`). `def self.foo` attaches the method to the class object itself, callable directly as `SomeClass.foo`, no instance required.

Cross-language comparison that made it click:
- **Python**: `self` there is just the conventional first parameter name of every instance method — an argument, not a definition-site marker. It answers a different question than Ruby's `self.` does.
- **C++**: `static` is the closer match. A plain method needs an instance (`EstateExecutor e; e.foo();`); a `static` method is called on the type directly (`EstateExecutor::foo()`) — same split as Ruby's `def self.foo`.

The bug this surfaced from: writing `def assemble_account_number` (no `self.`) inside `class EstateExecutor`, then calling `EstateExecutor.assemble_account_number(...)` directly with no instance ever created — `assert_respond_to` failed because the method only existed on instances, not on the class.

Found while working on: `last-will` — `EstateExecutor.assemble_account_number` / `assemble_code`, needed `self.` to be callable directly on the class.

## `raise` needs an instance (`.new`), not a bare call

`raise SomeError("message")` looks like it should work — it reads like passing a message to the exception — but Ruby parses `SomeError("message")` as a **method call** named `SomeError`, not as constructing an exception. Since no such method exists, it blows up with `NoMethodError: undefined method 'SomeError'` instead of raising the exception you meant.

The fix is to actually instantiate the exception first: `raise SomeError.new("message")`. `raise` expects an *exception object* (or a class it can instantiate itself with no custom message, e.g. bare `raise SomeError`) — it doesn't have special syntax that turns `ClassName(args)` into construction the way a real constructor call would in some other languages.

Found while working on: `simple-calculator` — `raise ArgumentError("Wrong argument")` raised `NoMethodError` instead of `ArgumentError`; fixed by writing `raise ArgumentError.new("Wrong argument")`.

## Default parameter values replace manual arity-checking for optional args

Ruby doesn't have method overloading (no picking a method body by argument count like Java/C++). The idiomatic way to make an argument optional is to give the parameter a default value in the signature: `def foo(name = "default")`. If the caller omits the argument, Ruby fills in the default; if they pass one, it overrides it.

This replaces the pattern of accepting a splat and then branching on how many arguments showed up:

```ruby
# Before: manual arity check
def foo(*args)
  case args.size
  when 0
    "default case"
  else
    "got #{args[0]}"
  end
end

# After: default value does the branching for you
def foo(name = "default value")
  "got #{name}"
end
```

The splat+case version works, but it's solving a problem Ruby already has a direct feature for — the default-value syntax collapses the whole branch into the method signature itself.

Found while working on: `two-fer` — original solution used `def self.two_fer(*args)` with `case args.size`; simplified to `def self.two_fer(name="you")`.

## `class` vs `module`: use a module when there's no instance state

A `class` is a blueprint for creating objects (`SomeClass.new`) that carry their own state and identity. If a "class" never uses `@instance_variables` and is only ever called via `self.` methods (never instantiated), the `class` keyword is misleading — it implies `.new` is a meaningful, intended operation, when actually it isn't.

A `module` can't be instantiated at all — `SomeModule.new` raises `NoMethodError`. Using `module` instead of `class` for a stateless container of methods communicates "this is just a namespace/utility grouping" through the type system itself, rather than relying on the reader to notice the class is never instantiated. The `def self.method_name` syntax for defining a module-level method is identical to the `def self.method_name` pattern for class-level methods (see the `def self.foo` entry above) — only the surrounding keyword changes.

```ruby
# Misleading: implies TwoFer.new has meaning, but it never does
class TwoFer
  def self.two_fer(name = "you")
    "One for #{name}, one for me."
  end
end

# Clearer: TwoFer is just a container, instantiation isn't even possible
module TwoFer
  def self.two_fer(name = "you")
    "One for #{name}, one for me."
  end
end
```

Found while working on: `two-fer` — automatic evaluator flagged the class-based solution; converted `class TwoFer` to `module TwoFer` with no other changes needed, tests still passed.

## Passing an array as one argument doesn't auto-splat into `*args`

`*args` collects **however many positional arguments the caller actually sent** into an Array — it doesn't reach into an array you pass and spread its contents out. Calling `foo(*args)` and calling `foo(some_array)` are different: the first spreads `some_array`'s elements as separate arguments, the second sends the whole array as a single argument.

```ruby
def value(*colors)
  colors
end

value("black", "white")    # => ["black", "white"]  — two args, collected normally
value(["black", "white"])  # => [["black", "white"]] — one arg (an array), wrapped again
value(*["black", "white"]) # => ["black", "white"]   — splatted at the call site, spreads out
```

The bug this caused: calling `ResistorColorDuo.value(%w[black white])` against `def self.value(*colors)` — `%w[...]` builds one array, passed as one argument, so `colors` ended up as `[["black", "white"]]` (an array *containing* the array) instead of the flat `["black", "white"]` expected. `color.to_sym` inside the loop then failed because `color` was itself an array, not a string. Fixed by dropping the splat entirely (`def self.value(colors)`) since the caller was always sending one array anyway — matching the parameter style to how the method is actually called, same principle as the `*` vs `**` entry above.

Found while working on: `resistor-color-duo` — `ResistorColorDuo.value`.

## `each_with_index` replaces a hand-rolled counter

If a block needs to know both the current element *and* its position, don't reach for a manually declared counter variable incremented inside the block — `each_with_index` hands you both directly as block parameters.

```ruby
# Before: manual counter, two jobs mixed into one block
exponent = 0
res = 0
colors.reverse.each { |color| res += VALUES[color.to_sym] * 10**exponent; exponent += 1 }

# After: index comes from the enumerator itself
res = 0
colors.reverse.each_with_index { |color, exponent| res += VALUES[color.to_sym] * 10**exponent }
```

The second version removes the state-management side effect (`exponent += 1`) from the block entirely — the block just computes, it doesn't also track its own progress through the loop.

Found while working on: `resistor-color-duo` — `ResistorColorDuo.value`, converting colors + position into a two-digit number arithmetically instead of via string concatenation.

## `find` returns one element, `select`/`filter` returns a subset — don't reach for the wrong one

`select`/`filter { |x| ... }` walks the whole collection and keeps every element where the block is truthy — it returns a **subset**, same type as the original, never fewer than "match or not" per element. It can't *extract a piece* of an element; it can only decide whether the whole element survives.

`find`/`detect { |x| ... }` walks the collection and returns the **first single element** where the block is truthy — nothing more, nothing less.

The bug this caused: trying to pull "the first letter of this word that's actually a letter" (to handle a word like `"_Not_"`, where index `0` is punctuation, not the real first letter) using `word.chars.select { |char| char.match(/[a-zA-Z]/) }` — that returns *every* letter in the word, not just the first. `find` was the right tool: `word.chars.find { |char| char.match(/[a-zA-Z]/) }` stops and returns as soon as it hits `"N"`.

```ruby
"_Not_".chars.select { |c| c.match(/[a-zA-Z]/) }  # => ["N", "o", "t"] — wrong tool, wrong shape
"_Not_".chars.find   { |c| c.match(/[a-zA-Z]/) }  # => "N"             — right tool
```

Found while working on: `acronym` — `Acronym.abbreviate`, extracting the first real letter of `"_Not_"` inside `"The Road _Not_ Taken"`.

## `gsub` + `scan` to extract "valid word chunks" beats `split` + filter-the-empties-after

`split(/[ -]/)` on a phrase with **consecutive** delimiters (e.g. `"Something - I made up"`, where a hyphen sits between two spaces) produces empty-string elements in the result — there's nothing between two adjacent delimiters. `split` also doesn't know anything about "what a valid word looks like"; it just cuts at the delimiter and leaves whatever punctuation happens to be at the edges (e.g. `"_Not_"` from `"The Road _Not_ Taken"`), pushing the cleanup into a later step.

Flipping the strategy — delete everything that *isn't* allowed first, then scan for word-shaped chunks — avoids both problems at once:

```ruby
value.gsub(/[^a-zA-Z0-9\s\-]/, "")   # strip anything that isn't a letter/digit/space/hyphen
     .scan(/\w+/)                    # pull out every maximal run of word-characters
     .map { |word| word[0].upcase }  # scan already guarantees each chunk starts on a real char
     .join
```

`\w+` (one-or-more word-characters) can never match an empty string and can never start mid-punctuation — so there's no empty-string case to `reject`, and no leading-underscore case to `find` around. The `gsub` pre-pass removes underscores/apostrophes/etc. before `scan` ever runs, so `\w+` only ever lands on real letters/digits.

Found while working on: `acronym` — `Acronym.abbreviate`; the `split` + `reject(&:empty?)` + `chars.find` version worked but took three separate fixes to reach; the `gsub`+`scan` version handles consecutive delimiters and stray punctuation in one pass.

## Character-class syntax: `[^...]` negates, `\s`/`\w` are shorthand classes

Inside a regex character class (`[...]`), a `^` as the **first character** flips its meaning to negation — `[^abc]` means "any character *not* a, b, or c." (Outside a character class, `^` means something unrelated: start-of-string/line anchor.)

`\s` and `\w` are built-in shorthand character classes: `\s` = any whitespace character (space, tab, newline); `\w` = any word character (letters, digits, and underscore). They can be used standalone (`\w+`) or combined inside a custom class (`[^a-zA-Z0-9\s\-]` = "not a letter, digit, whitespace, or hyphen").

Found while working on: `acronym` — reading `gsub(/[^a-zA-Z0-9\s\-]/, "")`, a solution pulled from outside the session rather than derived step-by-step.

## `attr_reader` takes a symbol naming the method to generate — not the ivar, not a call

`attr_reader :strength` reads oddly at first because none of the obvious guesses are right: `attr_reader @strength` passes the *value* of an as-yet-undefined ivar (nil), and `attr_reader strength` tries to *call* a method named `strength` as an argument, which doesn't exist yet either. `:strength` is a symbol — just a name/label, evaluated as itself, not looked up or dereferenced. `attr_reader` uses that name both to know which method to define and, by convention, which `@ivar` of the same name to return.

```ruby
attr_reader :strength   # correct — defines `strength` returning @strength
attr_reader @strength   # wrong — evaluates @strength (nil) as an argument
attr_reader strength    # wrong — tries to call a method `strength`, NoMethodError
```

Found while working on: `dnd-character` — exposing `@constitution`/`@strength`/etc. so the test's `character.constitution` calls had a method to land on.

## `self.foo` inside an instance method still means "call on this instance" — even for a name that's also a class method

Inside `initialize` (an instance method), `self` refers to the *instance* being built, not the class. Writing `self.modifier(...)` or even bare `modifier(...)` there looks for an **instance** method called `modifier` — it does not somehow reach up and find `def self.modifier` defined on the class, even though it's the "same class" conceptually. Class methods and instance methods are separate method tables; being inside the class body when either was defined doesn't link them.

```ruby
class DndCharacter
  def self.modifier(score)   # lives on the class's method table
    ((score - 10) / 2).floor
  end

  def initialize
    @constitution = ...
    modifier(@constitution)         # wrong — looks for an *instance* method `modifier`
    self.modifier(@constitution)    # wrong — same reason, self here is the instance
    DndCharacter.modifier(@constitution)  # right — names the class explicitly
  end
end
```

The fix is to name the class explicitly at the call site, since there's no instance-level shorthand that reaches a class method.

Found while working on: `dnd-character` — `initialize` computing `@hitpoints` via `modifier`, defined as `self.modifier` per the test's `DndCharacter.modifier(3)` call convention.

## `n.times { }` discards each block result; `n.times.map { }` collects them

`4.times { rand(1..6) }` runs the block 4 times purely for its side effects — the return value of `.times` (with a block) is the original integer, `4`, not an array of what the block produced. If you need the four individual results kept around (to later find the max/min/sum of them), that return value is useless.

Calling `.times` **without** a block returns an `Enumerator` instead of running anything yet. Chaining `.map { ... }` onto that enumerator is what actually runs the block N times *and* collects each result into an array — same trick as `Array.new(4) { rand(1..6) }`, just built from `.times` instead.

```ruby
4.times { rand(1..6) }        # => 4              (just the integer 4; rolls are discarded)
4.times.map { rand(1..6) }    # => [3, 6, 1, 4]    (an Enumerator, then .map collects the block's results)
```

Found while working on: `dnd-character` — `roll`, generating 4 dice results to keep (drop the lowest, sum the top three) rather than 4 throwaway rolls.

## `%i[...]` is `%w[...]` for symbols

`%w[strength dexterity]` builds an array of **strings**: `["strength", "dexterity"]`. `%i[strength dexterity]` builds an array of **symbols** directly: `[:strength, :dexterity]` — no separate `.map(&:to_sym)` pass needed afterward. Same bare-word, whitespace-separated literal syntax, just a different element type.

Found while working on: `dnd-character` — refactoring six hardcoded `@stat = ...` lines, wanting a literal list of stat names as symbols (for hash keys) rather than strings.

## `Enumerable#to_h` with a block skips the intermediate `.map` array

`array.map { |x| [x, f(x)] }.to_h` works, but it's two passes: `map` builds an Array of `[key, value]` pairs, then `.to_h` (no-block form — array-of-pairs → Hash) converts that array. `to_h` also accepts a block directly: `array.to_h { |x| [x, f(x)] }` does both steps in one call, same block, same `[key, value]` return shape per element, no intermediate array kept around.

```ruby
%i[strength dexterity].map { |name| [name, name.length] }.to_h   # two steps
%i[strength dexterity].to_h { |name| [name, name.length] }       # one step, same result
```

This was hard to find by guessing a *new* method name (tried grepping `instance_methods` for `/hash/i` — turned up nothing useful, since the method isn't named after "hash" at all). The lesson: not every transformation has its own uniquely-named method — sometimes an *existing* method (`to_h`, already known as a converter) gains an extra capability via an optional block, which a name-based search won't surface. Checking `ri Array#to_h` directly (rather than grepping for an unknown name) would have shown both forms.

Found while working on: `dnd-character` — collapsing six `@stat = roll` lines into one hash-building step over `%i[strength dexterity ...]`.

**Related trap:** `to_h`, `map`, and `each` all iterate once per element — they differ only in what they *collect* from the block's return value (`to_h` demands `[key, value]` pairs and builds a Hash; `map` collects anything into an Array; `each` collects nothing and just returns the original receiver). Pick the iteration method by what you actually want back, not by momentum from the method you used last. Using `.to_h { |stat| instance_variable_set(...) }` purely to loop — when the block's real job is a side effect and its return value is never used — raised `TypeError: wrong element type Integer at 0 (expected array)`, because `instance_variable_set`'s return value (the value just set, a plain Integer) doesn't satisfy `to_h`'s `[key, value]`-pair contract. `.each { ... }` was the right call: no return-value contract to satisfy, since nothing is being collected.

## `instance_variable_set` / `instance_variable_get`: dynamic ivar names, but they don't create reader methods

Normally you type an instance variable's name literally in source (`@strength = 14`) — Ruby parses `@strength` as "the ivar named strength" at parse time. When the name itself is only known at runtime (e.g. looping over `%i[strength dexterity]`), `object.instance_variable_set("@#{name}", value)` sets it dynamically instead. Two contract details that don't work the way they first look like they should:

- **The name argument must be a String or Symbol *starting with `@`*** — `instance_variable_set(:strength, 8)` raises `NameError: 'strength' is not allowed as an instance variable name`; it has to be `:@strength` or `"@strength"`. The `@` isn't optional decoration, it's how Ruby's object model spells "this is an ivar name" as opposed to any other kind of string.
- **It sets the ivar on *whatever object you call the method on*** — `some_symbol.instance_variable_set(...)` attaches the ivar to that symbol object, not to "the object being built." Inside `initialize`, that means calling it on `self` (the instance under construction), not on the loop variable holding the stat name.
- **Setting `@strength` this way does NOT create a `strength` reader method.** `attr_reader :strength` is what manufactures a `strength` method returning `@strength`; `instance_variable_set` only touches the ivar itself. Calling `.strength` afterward without a matching `attr_reader`/getter still raises `NoMethodError`, even though the ivar is genuinely set — proving the ivar exists requires reading it a different way, either `@strength` typed literally in code with a known name, or `instance_variable_get("@strength")` (a String/Symbol name again, not a bare identifier or its already-evaluated value) when the name is dynamic.

```ruby
%i[strength dexterity].each { |s| self.instance_variable_set("@#{s}", s.length) }
# ivars now exist: @strength, @dexterity

self.strength                          # NoMethodError — no reader method was ever defined
self.instance_variable_get("@strength")# => 8, works — reads by name, no method needed
@strength                              # => 8, works — direct literal ivar access
```

Found while working on: `dnd-character` — dynamically assigning `@strength`, `@dexterity`, etc. from a `stats` hash's keys inside `initialize`, replacing six hardcoded `@stat = roll...` lines.
