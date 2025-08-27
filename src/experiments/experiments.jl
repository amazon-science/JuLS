# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    Experiment

Abstract type representing an optimization experiment/problem.

This type serves as a base for defining specific optimization problems and provides
a framework for problem-specific implementations.

# Required Implementations
Any concrete subtype must implement:
- `n_decision_variables(::Experiment)`: Returns the number of decision variables
- `decision_type(::Experiment)`: Returns the type of decision variables
- `(::SimpleInitialization)(::Experiment, domains)`: Implementation for basic initialization

# Optional Implementations (with defaults)
- `default_init(::Experiment)`: Returns the initialization heuristic, default is SimpleInitialization()
- `default_neigh(e::Experiment)`: Returns the initialization heuristic, default is ExhaustiveNeighbourhood(2, n_decision_variables(e))
- `default_pick(::Experiment)`: Returns the move selection heuristic, default is GreedyMoveSelection()
- `default_using_cp(::Experiment)`: Whether to use constraint programming, default is true
"""
abstract type Experiment end
n_decision_variables(::Experiment) =
    error("You must implement the function n_decision_variables() for your experiment.")
decision_type(::Experiment) = error("You must implement a type for the problem's decision variables.")

include("knapsack/knapsack.jl")
include("tsp/tsp.jl")
include("graph_coloring/graph_coloring.jl")

"""
    init_model(
        e::Experiment;
        init::InitializationHeuristic = default_init(e),
        neigh::NeighbourhoodHeuristic = default_neigh(e),
        pick::MoveSelectionHeuristic = default_pick(e),
        using_cp::Bool = default_using_cp(e)
    )

Initializes an optimization model for the given experiment.

# Process
1. Generates variable domains
2. Creates initial solution
3. Generates decision variables
4. Creates and initializes DAG
5. Configures model with specified heuristics and CP settings 
"""
function init_model(
    e::Experiment;
    init::InitializationHeuristic = default_init(e),
    neigh::NeighbourhoodHeuristic = default_neigh(e),
    pick::MoveSelectionHeuristic = default_pick(e),
    using_cp::Bool = default_using_cp(e),
    display_cp::Bool = false,
)
    domains = generate_domains(e)
    init_solution = init(e)
    decision_variables = generate_decision_variables(e, domains, init_solution)
    dag = create_dag(e)
    init!(dag, DecisionVariablesArray(decision_variables))
    return Model(
        decision_variables,
        neigh,
        pick,
        dag;
        move_filter = using_cp ? CPEnumeration(init_cp_model(decision_variables, dag), display_cp) : DummyMoveFilter(),
    )
end

"""
    generate_decision_variables(
        e::Experiment,
        domains::Vector{Vector{T}},
        init_solution::Vector{T}
    ) where {T}

Creates decision variables for the experiment based on domains and initial solution.
"""
function generate_decision_variables(e::Experiment, domains::Vector{Vector{T}}, init_solution::Vector{T}) where {T}
    @assert n_decision_variables(e) == length(domains) == length(init_solution) "The initial solution and the set of domains must have the same size than the number of decision variables"
    type = decision_type(e)
    return DecisionVariable[
        DecisionVariable(i, type.(domains[i]), type(init_solution[i])) for i = 1:n_decision_variables(e)
    ]
end

default_init(::Experiment) = SimpleInitialization()
default_neigh(e::Experiment) = ExhaustiveNeighbourhood(2, n_decision_variables(e))
default_pick(::Experiment) = GreedyMoveSelection()
default_using_cp(::Experiment) = true

(::SimpleInitialization)(::Experiment, domains::Vector{Vector{<:DecisionValue}}) =
    error("You must implement at least the function (::SimpleInitialization)() for your experiment.")