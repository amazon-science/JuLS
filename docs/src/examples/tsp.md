# Traveling Salesman Problem Example

This example demonstrates how to solve a TSP using JuLS.jl.

## Problem Description

The Traveling Salesman Problem (TSP) involves:
- A set of cities with distances between them
- Goal: find the shortest route visiting all cities exactly once
- Return to the starting city

## Basic Usage

```julia
using JuLS

# Load a TSP instance
data_path = joinpath(JuLS.PROJECT_ROOT, "data", "tsp", "tsp_5_1")
experiment = TSPExperiment(data_path)

# Create and run the model
model = init_model(
    experiment;
    init = ChristofidesInitialization(),
    neigh = KOptNeighbourhood(5, 2),  # 5 moves, 2-opt
    pick = SimulatedAnnealing(100.0, 0.95),  # T0=100.0, α=0.95
    using_cp = true
)

# Optimize for 1000 iterations
optimize!(model; limit = IterationLimit(1000))

# Display results
println("Best tour length: ", model.best_solution.objective)
println("Tour: ", model.best_solution.values)
```

## Data Format

TSP data files contain distance matrices or coordinate information.

## Initialization Strategies

### Christofides Algorithm
Provides high-quality starting solutions:
```julia
init = ChristofidesInitialization()
```

### Simple Random
Random permutation of cities:
```julia
init = SimpleInitialization()
```

## Neighbourhood Strategies

### 2-opt Moves
Most common for TSP:
```julia
neigh = KOptNeighbourhood(5, 2)  # 5 moves, 2-opt
```

### 3-opt Moves
More thorough but slower:
```julia
neigh = KOptNeighbourhood(3, 3)  # 3 moves, 3-opt
```

## Move Selection

### Simulated Annealing
Recommended for TSP:
```julia
pick = SimulatedAnnealing(100.0, 0.95)  # T0=100.0, α=0.95
```

## Next Steps

- Try the [Graph Coloring Example](graph_coloring.md)
- Learn about [Custom Heuristics](../guide/heuristics.md)
- Explore [DAG construction](../guide/dag.md) for TSP
