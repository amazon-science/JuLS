# Model API

```@meta
CurrentModule = JuLS
```

The Model is the central component of JuLS that orchestrates the optimization process.

## Model Creation

```@docs
init_model
```

## Optimization

```@docs
optimize!
```

## Limits

- `IterationLimit(n)`: Stop after n iterations
- `TimeLimit(seconds)`: Stop after specified time in seconds

## Model Structure

The `Model` struct contains the following key fields:

- `experiment`: The problem definition
- `current_solution`: Current solution state
- `best_solution`: Best solution found so far
- `dag`: The constraint/objective DAG
- `heuristics`: Collection of heuristics used
- `metrics`: Performance metrics and statistics

## Solution Access

### Current Solution

Access the current solution state:

```julia
model.current_solution.values      # Current variable values
model.current_solution.objective   # Current objective value
model.current_solution.feasible    # Feasibility status
```

### Best Solution

Access the best solution found:

```julia
model.best_solution.values         # Best variable values
model.best_solution.objective      # Best objective value
```

## Metrics and Statistics

The model tracks various metrics during optimization:

```julia
model.run_metrics
```

## Example Usage

```julia
using JuLS

# Create experiment
data_path = joinpath(JuLS.PROJECT_ROOT, "data", "knapsack", "ks_4_0")
experiment = KnapsackExperiment(data_path)

# Initialize model
model = init_model(
    experiment;
    init = SimpleInitialization(),
    neigh = BinaryRandomNeighbourhood(10, 2),  # 10 moves, 2 variables per move
    pick = GreedyMoveSelection(),
    using_cp = true
)

# Optimize
optimize!(model; limit = IterationLimit(1000))

# Access results
println("Best objective: ", model.best_solution.objective)
println("Best solution: ", model.best_solution.values)
```

## Advanced Usage

### Custom Stopping Criteria

You can implement custom stopping criteria by extending the `Limit` types.

### Model Inspection

During optimization, you can inspect the model state:

```julia
# Check if current solution is feasible
is_feasible = model.current_solution.feasible

# Get constraint violations
violations = get_violations(model.dag)

# Access move history
recent_moves = model.move_history[end-10:end]
```

## Performance Considerations

### Memory Usage

- The model stores solution history for analysis
- Consider smaller neighbourhood sizes for large problems

### Threading

- JuLS can utilize multiple threads for move evaluation
- Start Julia with `--threads=auto` for best performance
- Some heuristics are inherently sequential

### Constraint Programming Integration

When `using_cp = true`:

- Move filtering is more efficient but requires more memory
- CP solver state is maintained alongside the DAG
- Infeasible moves are filtered before evaluation

## Troubleshooting

### Common Issues

1. **No improvements found**: Try different heuristic combinations
2. **Memory issues**: Reduce neighbourhood size or clear history
3. **Slow convergence**: Enable CP filtering or use better initialization
4. **Infeasible solutions**: Check constraint definitions in DAG
