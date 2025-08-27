# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    CPEnumeration <: AbstractMoveFilter

A constraint programming-based move filter that uses CP solver to enumerate feasible moves.

# Fields
- `cp_model::CPLSModel`: Constraint Programming model used for filtering moves

# Notes
The filtering is only possible if the set of moves is a LazyCartesianMoves
"""
struct CPEnumeration <: AbstractMoveFilter
    cp_model::CPLSModel
    display::Bool
end
CPEnumeration(cp_model::CPLSModel) = CPEnumeration(cp_model, false)

function filter_moves(model::Model, filter::CPEnumeration, moves::LazyCartesianMoves, ::TaskLocalRNG)
    relaxed_variables = Int[var.index for var in moves.selected_variables]
    current_solution = Int[v.value for v in model.current_solution.values]

    filtering_time = @elapsed filtered_moves = eval(filter.cp_model, current_solution, relaxed_variables)

    if filter.display
        display_filtering_performance(length(moves) - 1, length(filtered_moves), filtering_time)
    end

    return LazyFilteredMoves(
        moves.selected_variables,
        [map((t, v) -> t(v), decision_types(moves), move) for move in filtered_moves],
    )
end

"""
    display_filtering_performance(n_potential_solutions::Int, 
                                n_filtered_solutions::Int, 
                                filtering_time::Float64)

Displays performance metrics for the move CP filtering process.
"""
function display_filtering_performance(n_potential_solutions::Int, n_filtered_solutions::Int, filtering_time::Float64)
    println("\nFiltering time : ", filtering_time)
    println("Potential solutions : ", n_potential_solutions)
    println(
        "Feasible solutions found : ",
        n_filtered_solutions,
        " ($(round(n_filtered_solutions/n_potential_solutions*100, digits=2))%)",
    )
end


@testitem "filter_moves(::CPEnumeration) for knapsack" begin
    using Random
    e = JuLS.KnapsackExperiment(JuLS.PROJECT_ROOT * "/data/knapsack/ks_4_0")
    model = JuLS.init_model(e)

    moves = JuLS.LazyCartesianMoves(model.decision_variables)

    rng = MersenneTwister(0)

    filtered_moves = JuLS.filter_moves(model, moves)

    @test length(moves) == 16 + 1
    @test length(filtered_moves) == 9 + 1

    feasible_moves = BitMatrix([
        1 1 0 0
        1 0 0 1
        1 0 0 0
        0 1 0 1
        0 1 0 0
        0 0 1 1
        0 0 1 0
        0 0 0 1
        0 0 0 0
    ])

    for i = 1:9
        for j = 1:4
            @test filtered_moves[i].new_values[j].value == feasible_moves[i, j]
        end
    end
end

@testitem "filter_moves(::CPEnumeration) for graph coloring" begin
    using Random
    e = JuLS.GraphColoringExperiment(JuLS.PROJECT_ROOT * "/data/graph_coloring/gc_4_1", 4)
    model = JuLS.init_model(e)

    moves = JuLS.LazyCartesianMoves(model.decision_variables[[1, 2]])

    @test model.decision_variables[3].current_value.value == 2 # The current color is 2 for node 3
    @test model.decision_variables[4].current_value.value == 2 # The current color is 2 for node 4 

    rng = MersenneTwister(0)

    filtered_moves = JuLS.filter_moves(model, moves)

    @test length(moves) == 4 * 4 + 1 # Cartesian product of var 1, and 2

    @test length(filtered_moves) == 10

    feasible_moves = [
        3 4
        2 4
        1 4
        4 3
        2 3
        1 3
        4 1
        3 1
        2 1
    ]

    for i = 1:9
        for j = 1:2
            @test filtered_moves[i].new_values[j].value == feasible_moves[i, j]
        end
    end
    @test filtered_moves[10] == JuLS.NO_MOVE
end

