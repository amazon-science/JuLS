# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    KnapsackExperiment <: Experiment

Represents a 0-1 Knapsack Problem experiment instance.

# Fields
- `input_file::String`: Path to file containing problem data
- `α::Float64`: Penalty parameter for constraint violation
- `n_items::Int`: Number of items
- `capacity::Int`: Knapsack capacity
- `values::Vector{Int}`: Values of items
- `weights::Vector{Int}`: Weights of items

# File Format
Expected input file format:

n_items capacity
value1 weight1
value2 weight2
...
value_n weight_n
"""
struct KnapsackExperiment <: Experiment
    input_file::String
    α::Float64
    n_items::Int
    capacity::Int
    values::Vector{Int}
    weights::Vector{Int}

    KnapsackExperiment(input_file::String, α::Float64 = DEFAULT_PENALTY_PARAM) =
        open(input_file, "r") do f
            lines = readlines(f)
            n_items, capacity = parse.(Int, split(lines[1]))
            values, weights = zeros(Int, n_items), zeros(Int, n_items)
            for i = 1:n_items
                values[i], weights[i] = parse.(Int, split(lines[i+1]))
            end
            return new(input_file, α, n_items, capacity, values, weights)
        end
end

"""
    n_decision_variables(e::KnapsackExperiment)

The number of decision variables is equal to number of items.
"""
n_decision_variables(e::KnapsackExperiment) = e.n_items

"""
    decision_type(::KnapsackExperiment)

Decision is binary for item selection.
"""
decision_type(::KnapsackExperiment) = BinaryDecisionValue
generate_domains(e::KnapsackExperiment) = [[false, true] for _ = 1:e.n_items]

include("knapsack_init.jl")
include("knapsack_dag.jl")
include("knapsack_neigh.jl")

default_init(::KnapsackExperiment) = GreedyInitialization()
default_neigh(e::KnapsackExperiment) = ExhaustiveNeighbourhood(2, e.n_items)
default_pick(::KnapsackExperiment) = GreedyMoveSelection()
default_using_cp(::KnapsackExperiment) = true
create_dag(e::KnapsackExperiment) = create_knapsack_dag(e.weights, e.values, e.capacity, e.α)


@testitem "KnapsackExperiment α assignemnt" begin
    e1 = JuLS.KnapsackExperiment(JuLS.PROJECT_ROOT * "/data/knapsack/ks_4_0", 5.0)
    e2 = JuLS.KnapsackExperiment(JuLS.PROJECT_ROOT * "/data/knapsack/ks_4_0")

    @test e1.α == 5.0
    @test all(e1.values .== [8.0, 10.0, 15.0, 4.0])
    @test all(e1.weights .== [4.0, 5.0, 8.0, 3.0])
    @test e1.capacity == 11.0

    @test e2.α == JuLS.DEFAULT_PENALTY_PARAM
end

@testitem "init_model() heuristic assignment" begin
    struct MockMoveSelectionHeuristic <: JuLS.MoveSelectionHeuristic end

    # dummy heuristic to pick first evaluated move
    JuLS.pick_a_move(::MockMoveSelectionHeuristic, evaluated_moves::Vector{<:JuLS.MoveEvaluatorOutput}; rng) =
        evaluated_moves[1]

    struct MockNeighbourhoodHeuristic <: JuLS.NeighbourhoodHeuristic end

    # dummy neighbourhood generation
    function JuLS.get_neighbourhood(::MockNeighbourhoodHeuristic, model::JuLS.Model; rng)
        return [
            JuLS.Move([model.decision_variables[1]], [JuLS.BinaryDecisionValue(true)]),
            JuLS.Move([model.decision_variables[2]], [JuLS.BinaryDecisionValue(true)]),
            JuLS.Move([model.decision_variables[3]], [JuLS.BinaryDecisionValue(true)]),
            JuLS.Move([model.decision_variables[4]], [JuLS.BinaryDecisionValue(true)]),
        ]
    end

    e = JuLS.KnapsackExperiment(JuLS.PROJECT_ROOT * "/data/knapsack/ks_4_0", 10.0)
    model = JuLS.init_model(
        e;
        init = JuLS.SimpleInitialization(),
        neigh = MockNeighbourhoodHeuristic(),
        pick = MockMoveSelectionHeuristic(),
    )
    JuLS.optimize!(model; limit = JuLS.IterationLimit(1))

    mock_obj = model.current_solution.objective # keep track of objective for later

    # did the first move get selected?
    @test model.current_solution.values == [
        JuLS.BinaryDecisionValue(true),
        JuLS.BinaryDecisionValue(false),
        JuLS.BinaryDecisionValue(false),
        JuLS.BinaryDecisionValue(false),
    ]

    model = JuLS.init_model(e; init = JuLS.SimpleInitialization())
    JuLS.optimize!(model; limit = JuLS.IterationLimit(1))

    @test model.current_solution.objective < mock_obj # default heuristics should default to something better than dummy
end