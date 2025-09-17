# Graph Coloring Problem Example

This example demonstrates how to solve a graph coloring problem using JuLS.jl.

## Problem Description

The Graph Coloring Problem involves:
- A graph with vertices and edges
- Goal: assign colors to vertices such that no adjacent vertices have the same color
- Minimize the number of colors used

## Basic Usage

```julia
using JuLS

# Load a graph coloring instance
data_path = joinpath(JuLS.PROJECT_ROOT, "data", "graph_coloring", "gc_4_1")
experiment = GraphColoringExperiment(data_path, 4)  # 4 colors max

# Create and run the model
model = init_model(
    experiment;
    init = GreedyInitialization(),
    neigh = RandomNeighbourhood(4, 1),  # 4 variables, 1 to move
    pick = GreedyMoveSelection(),
    using_cp = true
)

# Optimize for 1000 iterations
optimize!(model; limit = IterationLimit(1000))

# Display results
println("Colors used: ", model.best_solution.objective)
println("Coloring: ", model.best_solution.values)
```

## Data Format

Graph coloring data files specify the edges in the graph.

## Initialization Strategies

### Greedy Coloring
Assigns colors greedily:
```julia
init = GreedyInitialization()
```

### Random Initialization
Random color assignment:
```julia
init = SimpleInitialization()
```

## Neighbourhood Strategies

### Random Neighbourhood
Changes colors of random vertices:
```julia
neigh = RandomNeighbourhood()
```

## Move Selection

### Greedy Selection
Always picks the best move:
```julia
pick = GreedyMoveSelection()
```

## Next Steps

- Return to [Knapsack Example](knapsack.md)
- Learn about [Custom Experiments](../guide/experiments.md)
- Explore [Heuristic combinations](../guide/heuristics.md)
