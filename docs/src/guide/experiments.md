# Creating Experiments

Experiments in JuLS define the structure and data of optimization problems. They serve as the foundation for setting up your optimization model.

## What is an Experiment?

An experiment is a Julia struct that inherits from the abstract type `Experiment` and encapsulates:

- Problem instance data
- Decision variable definitions
- Domain generation logic
- Problem-specific initialization methods

## Required Interface

Every experiment must implement the following functions:

### Core Functions

```julia
# Define the number of decision variables
JuLS.n_decision_variables(e::YourExperiment)::Int

# Define the type of decision variables
JuLS.decision_type(e::YourExperiment)::Type

# Generate domains for decision variables
JuLS.generate_domains(e::YourExperiment)::Vector

# Create the DAG representation of the problem
JuLS.create_dag(e::YourExperiment)::DAG
```

### Initialization Function

```julia
# Define how to initialize solutions
(::SimpleInitialization)(e::YourExperiment)::Vector
```

## Decision Variable Types

JuLS supports several decision variable types:

- `BinaryDecisionValue`: For 0/1 variables
- `IntDecisionValue`: For integer variables with bounds
- `PermutationDecisionValue`: For permutation problems

## Example: Custom Experiment

Here's how to create a simple custom experiment:

```julia
using JuLS

# Define your experiment struct
struct MyCustomExperiment <: JuLS.Experiment
    n_vars::Int
    bounds::Vector{Tuple{Int,Int}}
    objective_weights::Vector{Float64}
end

# Implement required functions
function JuLS.n_decision_variables(e::MyCustomExperiment)
    return e.n_vars
end

function JuLS.decision_type(e::MyCustomExperiment)
    return JuLS.IntDecisionValue
end

function JuLS.generate_domains(e::MyCustomExperiment)
    domains = []
    for (lower, upper) in e.bounds
        push!(domains, lower:upper)
    end
    return domains
end

function JuLS.create_dag(e::MyCustomExperiment)
    # Create your DAG here
    # This defines the constraints and objectives
    dag = JuLS.DAG()
    
    # Add invariants to represent your problem
    # See the DAG guide for details
    
    return dag
end

# Define initialization
function (::SimpleInitialization)(e::MyCustomExperiment)
    solution = []
    for (lower, upper) in e.bounds
        push!(solution, rand(lower:upper))
    end
    return solution
end
```

## Built-in Experiments

JuLS provides several built-in experiments:

### KnapsackExperiment

For binary knapsack problems:

```julia
experiment = KnapsackExperiment("path/to/data/file")
```

The data file should contain:
- First line: number of items, knapsack capacity
- Following lines: weight, value for each item

### TSPExperiment

For traveling salesman problems:

```julia
experiment = TSPExperiment("path/to/tsp/file")
```

Supports standard TSP file formats with distance matrices.

### GraphColoringExperiment

For graph coloring problems:

```julia
experiment = GraphColoringExperiment("path/to/graph/file", n_colors)
```

Where `n_colors` is the number of colors to use. The graph file should specify edges in the graph.

## Best Practices

### Data Loading

- Load and validate data in the constructor
- Store preprocessed data as struct fields
- Handle file format errors gracefully

```julia
struct MyExperiment <: JuLS.Experiment
    data::Matrix{Float64}
    
    function MyExperiment(filepath::String)
        # Load and validate data
        if !isfile(filepath)
            error("Data file not found: $filepath")
        end
        
        data = load_data(filepath)
        validate_data(data)
        
        new(data)
    end
end
```

### Domain Generation

- Use efficient data structures for large domains
- Consider domain reduction techniques
- Cache domains if they're expensive to compute

```julia
function JuLS.generate_domains(e::MyExperiment)
    # Cache domains if needed
    if !isdefined(e, :cached_domains)
        e.cached_domains = compute_domains(e)
    end
    return e.cached_domains
end
```

### DAG Construction

- Keep DAG construction modular
- Use helper functions for complex constraints
- Document the problem formulation

```julia
function JuLS.create_dag(e::MyExperiment)
    dag = JuLS.DAG()
    
    # Add constraints systematically
    add_capacity_constraints!(dag, e)
    add_objective_function!(dag, e)
    add_problem_specific_constraints!(dag, e)
    
    return dag
end
```

## Testing Your Experiment

Always test your experiment implementation:

```julia
# Test basic functionality
experiment = MyCustomExperiment(...)

@test JuLS.n_decision_variables(experiment) > 0
@test JuLS.decision_type(experiment) <: JuLS.DecisionValue
@test length(JuLS.generate_domains(experiment)) == JuLS.n_decision_variables(experiment)

# Test with a model
model = init_model(experiment)
@test model isa JuLS.Model

# Test optimization
optimize!(model; limit = IterationLimit(10))
@test model.best_solution.objective isa Number
```

## Common Pitfalls

1. **Inconsistent dimensions**: Ensure all arrays have consistent sizes
2. **Invalid domains**: Check that domains are non-empty and valid
3. **Missing exports**: Don't forget to export your experiment type
4. **Performance issues**: Profile domain generation and DAG construction for large instances

## Next Steps

- Learn about [DAG and Invariants](dag.md) to define your problem constraints
- Explore [Heuristics](heuristics.md) to customize the optimization process
- See complete [Examples](../examples/knapsack.md) for reference implementations
