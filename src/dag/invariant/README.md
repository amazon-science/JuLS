## Invariants
In the CBLS module of JuLS, constraints are modeled using **invariants**, also known as one-way constraints. An invariant is a function that defines the value of a single output variable based on one or more input variables, and it updates incrementally as those inputs change. This design avoids full re-computation, relying instead on efficient, local updates. By chaining invariants together, JuLS constructs a directed acyclic graph where each node represents an invariant and edges represent data dependencies. This DAG forms the backbone of constraint propagation.

This fits with JuLS’s messaging system: a message represents the current value of a variable, while a delta describes a proposed change, allowing the system to evaluate the impact of a move before committing it.

---

### Characteristics of an Invariant:
- **Reactive**: It observes changes in one or more decision variables.
- **Incremental**: It can compute the effect of a change ($\delta$) without full reevaluation.
- **Composable**: It can be nested or combined to represent complex expressions.
- **Stateful or Stateless**: Some invariants maintain internal state (e.g., `MaximumInvariant`), while others are pure functions of their inputs (e.g., `ElementInvariant`, `AmongInvariant`)

---


### Defining an Invariant

To define an invariant in JuLS's CBLS module, the following interface is typically implemented:

1. **`init!(invariant, messages)`**
   Initializes the invariant from its parent variable messages. This sets up the internal state, if any, and returns a message representing the current value.

2. **`eval(invariant, messages)`**
   Recomputes the invariant's value given new full values of its parents. This is used when a full evaluation is necessary (e.g., after initialization or full re-evaluation).

3. **`eval(invariant, deltas)`**
   Computes the change ($\delta$) in the invariant’s value when some of its parents change. This allows the solver to assess the impact of a move before committing.

4. **`commit!(invariant, deltas)`**
   Applies the move to the invariant’s internal state. Only used for stateful invariants.


