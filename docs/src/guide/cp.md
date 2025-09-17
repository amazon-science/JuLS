# Constraint Programming

JuLS integrates Constraint Programming (CP) to efficiently filter infeasible moves during local search optimization.

## What is CP Integration?

When you set `using_cp = true` in your model, JuLS:
- Converts the DAG to CP constraints
- Uses CP propagation to filter moves
- Maintains consistency between DAG and CP representations

## Benefits of CP Integration

### Move Filtering
- Eliminates infeasible moves before evaluation
- Reduces wasted computation on invalid solutions
- Improves search efficiency

### Constraint Propagation
- Automatically enforces constraint consistency
- Detects infeasibility early
- Provides domain reduction

## How It Works

### DAG to CP Conversion
The DAG invariants are automatically converted to CP constraints:

```julia
# DAG invariants
sum_invariant = ScalarProductInvariant(weights)
comparator = ComparatorInvariant(capacity)

# Becomes CP constraint
sum_constraint = SumLessThan(weights, capacity)
```

### Move Evaluation Process
1. Generate candidate moves from neighbourhood
2. Apply CP filtering to eliminate infeasible moves
3. Evaluate remaining moves using DAG
4. Select best move using move selection heuristic

## CP Variable Types

### IntVariable
For integer decision variables:
```julia
var = IntVariable(1, 10)  # Domain [1, 10]
```

### BoolVariable  
For binary decision variables:
```julia
var = BoolVariable()  # Domain {0, 1}
```

## CP Constraints

JuLS provides several built-in CP constraints:

### Basic Constraints
- `Equal`: Variable equality
- `NotEqual`: Variable inequality
- `SumLessThan`: Weighted sum constraints

### Advanced Constraints
- `AllDifferent`: All variables must be different
- `Among`: Count constraints
- `Element`: Array indexing

## Example: Knapsack with CP

```julia
using JuLS

# Load experiment
experiment = KnapsackExperiment("data/knapsack/ks_4_0")

# Create model with CP enabled
model = init_model(
    experiment;
    init = SimpleInitialization(),
    neigh = BinaryRandomNeighbourhood(10, 2),  # n_moves, n_vars
    pick = GreedyMoveSelection(),
    using_cp = true  # Enable CP filtering
)

# Optimize - CP will filter infeasible moves
optimize!(model; limit = IterationLimit(1000))
```

## Next Steps

- See [Examples](../examples/knapsack.md) for CP usage in practice
- Learn about [DAG and Invariants](dag.md) for constraint modeling
- Explore the [API Reference](../api/constraints.md) for detailed CP documentation
