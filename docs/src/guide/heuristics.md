# Heuristics

Heuristics in JuLS control how the optimization process explores the solution space. They are divided into three main categories: initialization, neighbourhood exploration, and move selection.

## Types of Heuristics

### 1. Initialization Heuristics

These determine the starting solution for optimization.

#### SimpleInitialization
Random initialization within variable domains:
```julia
init = SimpleInitialization()
```

#### GreedyInitialization
Problem-specific greedy construction:
```julia
init = GreedyInitialization()
```

#### ChristofidesInitialization
Specialized for TSP problems using the Christofides algorithm:
```julia
init = ChristofidesInitialization()
```

### 2. Neighbourhood Heuristics

These define how to explore the solution space by generating moves.

#### RandomNeighbourhood
Randomly selects variables and generates moves:
```julia
neigh = RandomNeighbourhood(n_vars, n_to_move)  # n_vars total, n_to_move selected
```

#### BinaryRandomNeighbourhood
Specialized for binary problems:
```julia
neigh = BinaryRandomNeighbourhood(n_moves, n_vars)  # n_moves generated, n_vars flipped each
```

#### SwapNeighbourhood
Generates swap moves between variables:
```julia
neigh = SwapNeighbourhood()  # No parameters needed
```

#### KOptNeighbourhood
k-opt moves for permutation problems:
```julia
neigh = KOptNeighbourhood(n_moves, k)  # n_moves generated, k variables each
```

### 3. Move Selection Heuristics

These decide which moves to accept during optimization.

#### GreedyMoveSelection
Always accepts the best improving move:
```julia
pick = GreedyMoveSelection()
```

#### SimulatedAnnealing
Temperature-based acceptance with cooling:
```julia
pick = SimulatedAnnealing(T0=100.0, α=0.95)
```

#### Metropolis
Metropolis criterion with fixed temperature:
```julia
pick = Metropolis(T=10.0)
```

## Custom Heuristics

You can create custom heuristics by implementing the appropriate interfaces.

### Custom Initialization

```julia
struct MyInitialization <: InitializationHeuristic
    # Custom parameters
end

function (init::MyInitialization)(experiment::MyExperiment)
    # Return initial solution vector
    return initial_solution
end
```

### Custom Neighbourhood

```julia
struct MyNeighbourhood <: NeighbourhoodHeuristic
    # Custom parameters
end

function get_neighbourhood(neigh::MyNeighbourhood, model::Model)
    # Return vector of possible moves
    return moves
end
```

### Custom Move Selection

```julia
struct MyMoveSelection <: MoveSelectionHeuristic
    # Custom parameters
end

function pick_a_move(picker::MyMoveSelection, evaluated_moves::Vector{<:MoveEvaluatorOutput})
    # Return selected move or nothing
    return selected_move
end
```

## Heuristic Combinations

Different heuristic combinations work better for different problem types:

### For Binary Problems
```julia
model = init_model(
    experiment;
    init = GreedyInitialization(),
    neigh = BinaryRandomNeighbourhood(10, 2),
    pick = GreedyMoveSelection()
)
```

### For Permutation Problems
```julia
model = init_model(
    experiment;
    init = ChristofidesInitialization(),  # TSP-specific
    neigh = KOptNeighbourhood(5, 2),  # 5 moves, 2-opt
    pick = SimulatedAnnealing(100.0, 0.95)  # T0=100.0, α=0.95
)
```

### For General Integer Problems
```julia
model = init_model(
    experiment;
    init = SimpleInitialization(),
    neigh = RandomNeighbourhood(10, 2),  # 10 variables, 2 to move
    pick = Metropolis(5.0)  # T=5.0
)
```


## Next Steps

- See [Examples](../examples/knapsack.md) for heuristic usage in practice
- Learn about [Constraint Programming](cp.md) integration
- Explore the [API Reference](../api/heuristics.md) for detailed documentation
