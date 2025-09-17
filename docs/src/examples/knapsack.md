# Knapsack Problem Example

This example demonstrates how to solve a knapsack problem using JuLS.jl.

## Problem Description

The knapsack problem is a classic optimization problem where you have:
- A knapsack with limited capacity
- A set of items, each with a weight and value
- Goal: maximize total value while staying within capacity constraint

## Basic Usage

```julia
using JuLS

# Load a knapsack instance
data_path = joinpath(JuLS.PROJECT_ROOT, "data", "knapsack", "ks_4_0")
experiment = KnapsackExperiment(data_path)

# Create and run the model
model = init_model(
    experiment;
    init = SimpleInitialization(),
    neigh = BinaryRandomNeighbourhood(10, 2),  # 10 moves, 2 variables per move
    pick = GreedyMoveSelection(),
    using_cp = true
)

# Optimize for 1000 iterations
optimize!(model; limit = IterationLimit(1000))

# Display results
println("Best objective value: ", model.best_solution.objective)
println("Items selected: ", model.best_solution.values)
```

## Data Format

The knapsack data file format is:
```
n_items capacity
weight_1 value_1
weight_2 value_2
...
weight_n value_n
```

Example file content:
```
4 11
8 4
10 5
15 8
4 3
```

This represents:
- 4 items with capacity 11
- Item 1: weight=8, value=4
- Item 2: weight=10, value=5
- Item 3: weight=15, value=8
- Item 4: weight=4, value=3

## Advanced Configuration

### Custom Initialization

Use greedy initialization for better starting solutions:

```julia
model = init_model(
    experiment;
    init = GreedyInitialization(),  # Start with greedy solution
    neigh = BinaryRandomNeighbourhood(10, 2),
    pick = GreedyMoveSelection(),
    using_cp = true
)
```

### Different Neighbourhood Strategies

Try different neighbourhood exploration strategies:

```julia
# Single bit flip neighbourhood
model = init_model(
    experiment;
    neigh = BinarySingleNeighbourhood(),
    # ... other parameters
)

# Exhaustive neighbourhood (for small problems)
model = init_model(
    experiment;
    neigh = ExhaustiveNeighbourhood(),
    # ... other parameters
)
```

### Move Selection Heuristics

Experiment with different move selection strategies:

```julia
# Simulated annealing
model = init_model(
    experiment;
    pick = SimulatedAnnealing(100.0, 0.95),  # T0=100.0, α=0.95
    # ... other parameters
)

# Metropolis criterion
model = init_model(
    experiment;
    pick = Metropolis(10.0),  # T=10.0
    # ... other parameters
)
```

## Common Issues

1. **Infeasible solutions**: Check that your initialization respects capacity constraints
2. **No improvements**: Try different heuristic combinations or increase iteration limit
3. **Slow convergence**: Enable CP filtering or use better initialization strategies

## Next Steps

- Try the [TSP Example](tsp.md) for a different problem type
- Learn about [Custom Heuristics](../guide/heuristics.md)
- Explore the [DAG structure](../guide/dag.md) for constraint modeling
