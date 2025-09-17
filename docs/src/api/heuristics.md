# Heuristics API

```@meta
CurrentModule = JuLS
```

The Heuristics API provides the optimization strategies for initialization, neighbourhood exploration, and move selection.

## Initialization Heuristics

```@docs
SimpleInitialization
GreedyInitialization
ChristofidesInitialization
```

## Neighbourhood Heuristics

```@docs
RandomNeighbourhood
BinaryRandomNeighbourhood
BinarySingleNeighbourhood
SwapNeighbourhood
KOptNeighbourhood
ExhaustiveNeighbourhood
GreedyNeighbourhood
```

## Move Selection Heuristics

```@docs
GreedyMoveSelection
SimulatedAnnealing
Metropolis
```

## Custom Heuristics

To create custom heuristics, implement the appropriate abstract type:

- `InitializationHeuristic`: For custom initialization strategies
- `NeighbourhoodHeuristic`: For custom neighbourhood exploration
- `MoveSelectionHeuristic`: For custom move selection criteria

## Example Usage

```julia
using JuLS

# Initialize with different heuristics
model = init_model(
    experiment;
    init = GreedyInitialization(),
    neigh = KOptNeighbourhood(5, 2),  # n_moves, k
    pick = SimulatedAnnealing(100.0, 0.95)  # T0, α
)
