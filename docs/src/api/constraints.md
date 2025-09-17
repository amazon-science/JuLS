# Constraints API

```@meta
CurrentModule = JuLS
```

The Constraints API provides the constraint programming functionality for move filtering.

## CP Variables

### IntVariable

```@docs
IntVariable
```

### BoolVariable

```@docs
BoolVariable
```

## CP Constraints

### Basic Constraints

```@docs
Equal
NotEqual
SumLessThan
```


## Integration with DAG

CP constraints are automatically generated from DAG invariants when `using_cp = true`.
