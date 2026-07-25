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
