# JuLS.jl Documentation

```@meta
CurrentModule = JuLS
```

**JuLS** is a Julia Local Search solver that combines Constraint Based Local Search (CBLS) and Constraint Programming (CP) to solve Constraint Optimization Problems (COP). It is designed as an open source project that provides the capability to solve combinatorial and black box optimization problems.

## Key Features

- **Hybrid Approach**: Combines CBLS and CP for efficient optimization
- **Flexible Architecture**: Modular design allowing custom heuristics and constraints
- **Multiple Problem Types**: Support for various combinatorial optimization problems
- **Extensible**: Easy to add new problem types and solution strategies

## Quick Start

```julia
using JuLS

# Create an experiment (e.g., Knapsack problem)
data_path = joinpath(JuLS.PROJECT_ROOT, "data", "knapsack", "ks_4_0")
experiment = KnapsackExperiment(data_path)

# Initialize a model
model = init_model(
    experiment; 
    init = SimpleInitialization(),
    neigh = BinaryRandomNeighbourhood(10, 2),  # 10 moves, 2 variables per move
    pick = GreedyMoveSelection(),
    using_cp = true
)

# Optimize
optimize!(model; limit = IterationLimit(100))

# Check results
println("Best objective: ", model.best_solution.objective)
println("Best solution: ", model.best_solution.values)
```

## Architecture Overview

JuLS is built around several key components:

- **Model**: The Local Search model that optimizes the problem
- **DAG**: Directed Acyclic Graph structure for constraint and objective evaluation
- **CP**: Constraint Programming solver for efficient move filtering
- **Heuristics**: Initialization, neighbourhood, and move selection strategies
- **Experiments**: Problem-specific implementations and data handling

## Supported Problems

JuLS comes with built-in support for several classic optimization problems:

- **Knapsack Problem**: Binary optimization with capacity constraints
- **Traveling Salesman Problem (TSP)**: Route optimization with distance minimization
- **Graph Coloring Problem**: Vertex coloring with adjacency constraints

Although, JuLS is designed to build custom experiments, especially giving the possibility to solve highly-dimensional combinatorial and black box optimization problems.

## Getting Help

- Check the [Getting Started](getting_started.md) guide for installation and basic usage
- Browse the User Guide for detailed explanations of core concepts
- See Examples for complete problem implementations
- Refer to the API Reference for detailed function documentation

## License

JuLS is licensed under the Apache License 2.0. See the [LICENSE](https://github.com/amazon-science/JuLS/blob/main/LICENSE) file for details.
