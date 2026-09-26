# Ruby Takeaways

## Concepts & Patterns

**Realization: Functional Counting (Filtering + Tallying)**

When counting elements that match a specific condition, use `Collection#count { |item, item2| condition }` instead of manually initializing a counter and using an `if` statement inside an iteration loop. This combines the *filtering* (deciding which items pass the test) and the *counting* (the final tally) into a single, declarative operation, leading to shorter, cleaner, and less state-dependent code.