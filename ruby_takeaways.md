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
