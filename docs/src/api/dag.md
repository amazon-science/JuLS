# DAG API

```@meta
CurrentModule = JuLS
```

The DAG (Directed Acyclic Graph) API provides the core constraint and objective modeling functionality.

## DAG Construction

```@docs
DAG
```

## Invariants

Invariants are the building blocks of the DAG that represent constraints and computations.

### Arithmetic Invariants

```@docs
ScalarProductInvariant
SumInvariant
```

### Comparison Invariants

```@docs
ComparatorInvariant
```

### Boolean Invariants

```@docs
AndInvariant
OrInvariant
```

### Specialized Invariants

```@docs
AllDifferentInvariant
AmongInvariant
ElementInvariant
```

## DAG Operations

### Adding Invariants

```julia
# Add an invariant to the DAG
invariant_id = add_invariant!(dag, ScalarProductInvariant(weights); variable_parent_indexes = [1, 2, 3])
```

## Message Passing

The DAG uses message passing for efficient computation:

### Message Types

- `FullMessage`: Complete state information
- `Delta`: Incremental changes only


## Example Usage

```julia
using JuLS

# Create a DAG for a simple problem
dag = JuLS.DAG(3)  # 3 decision variables

# Add scalar product invariant
weights = [2.0, 3.0, 1.0]
sum_id = add_invariant!(dag, ScalarProductInvariant(weights); variable_parent_indexes = [1, 2, 3])

# Add comparator for constraint
capacity = 10.0
constraint_id = add_invariant!(dag, ComparatorInvariant(capacity); variable_parent_indexes = [1, 2, 3])

# Connect sum to constraint
connect!(dag, sum_id, constraint_id)

# Set objective
objective_weights = [5.0, 4.0, 3.0]
obj_id = add_invariant!(dag, ScalarProductInvariant(objective_weights); variable_parent_indexes= [1, 2, 3])
add_invariant!(dag, ObjectiveInvariant(); invariant_parent_indexes= [obj_id])
```


## Performance Considerations

### Memory Usage
- DAGs store computation history for efficiency
- Consider clearing history for long runs
- Monitor memory usage for large problems

### Computation Efficiency
- Use appropriate invariant types
- Minimize unnecessary connections
- Batch updates when possible
