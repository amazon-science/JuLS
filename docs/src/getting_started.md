# Getting Started

This guide will help you get up and running with JuLS.jl quickly.

## Installation

### Prerequisites

- Julia 1.6 or later
- Git (for cloning the repository)

### Installing JuLS

Currently, JuLS is not registered in the Julia General registry. To install it, clone the repository and activate the project:

```bash
git clone https://github.com/amazon-science/JuLS.git
cd JuLS
julia --threads=auto --project=.
```

In the Julia REPL, instantiate the project:

```julia
using Pkg
Pkg.instantiate()
```

## Your First Optimization

Let's solve a simple knapsack problem to get familiar with JuLS:

```julia
using JuLS

# Load example data
data_path = joinpath(JuLS.PROJECT_ROOT, "data", "knapsack", "ks_4_0")
experiment = KnapsackExperiment(data_path)

# Create a model with default settings
model = init_model(
    experiment;
    init = SimpleInitialization(),
    neigh = BinaryRandomNeighbourhood(10, 2),  # 10 moves, 2 variables per move
    pick = GreedyMoveSelection(),
    using_cp = true
)

# Optimize for 100 iterations
optimize!(model; limit = IterationLimit(100))

# Check the results
println("Best objective: ", model.best_solution.objective)
println("Best solution: ", model.best_solution.values)
```

## Understanding the Components

### Experiments

An experiment defines the problem structure and data. JuLS provides built-in experiments for:

- `KnapsackExperiment`: Binary knapsack problems
- `TSPExperiment`: Traveling salesman problems  
- `GraphColoringExperiment`: Graph coloring problems

### Initialization Heuristics

These determine the starting solution:

- `SimpleInitialization()`: Random initialization
- `GreedyInitialization()`: Greedy construction (problem-specific)
- `ChristofidesInitialization()`: For TSP problems

### Neighbourhood Heuristics

These define how to explore the solution space:

- `BinaryRandomNeighbourhood(n_moves, n_vars)`: For binary problems - generates n_moves by flipping n_vars variables
- `SwapNeighbourhood()`: Swap-based moves between variables
- `KOptNeighbourhood(n_moves, k)`: k-opt moves for permutation problems - generates n_moves with k variables each
- `RandomNeighbourhood(n_vars, n_to_move)`: Random variable selection - selects n_to_move from n_vars variables

### Move Selection Heuristics

These choose which moves to accept:

- `GreedyMoveSelection()`: Always pick the best improving move
- `SimulatedAnnealing(T0, α)`: Temperature-based acceptance with cooling (T0=initial temp, α=cooling rate)
- `Metropolis(T)`: Metropolis criterion with fixed temperature T

## Next Steps

- Read the [User Guide](guide/experiments.md) for detailed explanations
- Check out the [Examples](examples/knapsack.md) for complete problem implementations
- Browse the [API Reference](api/model.md) for detailed function documentation

## Common Issues

### Threading

JuLS can benefit from multiple threads. Start Julia with:

```bash
julia --threads=auto --project=.
```

### Memory Usage

For large problems, consider:
- Using smaller neighbourhood sizes
- Implementing custom move filters
- Monitoring memory usage during optimization

### Performance Tips

- Enable constraint programming with `using_cp = true` for better move filtering
- Experiment with different heuristic combinations
- Use time limits for consistent benchmarking: `TimeLimit(60)` for 60 seconds
