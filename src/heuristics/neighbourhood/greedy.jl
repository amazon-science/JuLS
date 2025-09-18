# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    GreedyNeighbourhood <: NeighbourhoodHeuristic

A neighbourhood generation strategy that greedily explores variables based on their potential improvement at initialization.

# Fields
- `queue::Vector{LazyCartesianMoves}`: Ordered queue of moves to explore
- `_is_init::Bool`: Flag indicating if the neighbourhood has been initialized

# Description
This heuristic evaluates each variable's potential contribution to improvement
and orders the exploration based on these evaluations. Variables are explored
in order of their potential impact on the objective function.
"""
mutable struct GreedyNeighbourhood <: NeighbourhoodHeuristic
    queue::Vector{LazyCartesianMoves}
    _is_init::Bool
end
GreedyNeighbourhood() = GreedyNeighbourhood([], false)

"""
    eval_variable(variable_id::Int, model::Model)
    eval_variable(variable_id::Int, model::Model, T::Type{<:MoveEvaluatorInput})

Evaluates all possible value changes for a single variable.
"""
eval_variable(variable_id::Int, model::Model) = eval_variable(variable_id, model, Move)
function eval_variable(variable_id::Int, model::Model, T::Type{<:MoveEvaluatorInput})
    variable = decision_variables(model)[variable_id]
    moves = [Move([variable], [value]) for value in variable.domain]

    evaluated_moves = evaluate_moves(model, T, moves)

    return evaluated_moves
end

"""
    get_neighbourhood(
        h::GreedyNeighbourhood,
        model::Model;
        rng = Random.GLOBAL_RNG,
        mask = _default_mask(h, model)
    )

Initializes the neighbourhood on first call by ordering moves based on their potential improvement.
At each iteration gets the next set of moves to explore based on greedy ordering. 
Returns moves in order of their potential improvement

# Returns
- If queue is not empty: Next set of moves from the queue
- If queue is empty: Array containing only NO_MOVE
"""
function get_neighbourhood(
    h::GreedyNeighbourhood,
    model::Model;
    rng = Random.GLOBAL_RNG,
    mask = _default_mask(h, model),
)
    if !h._is_init
        h.queue = init_neighbourhood(h, model)
    end
    if !isempty(h.queue)
        return popfirst!(h.queue)
    end
    return [NO_MOVE]
end

"""
    best_feasible_delta_obj(evaluated_moves::Vector{<:MoveEvaluatorOutput})

Finds the best objective delta among the feasible moves.
"""
best_feasible_delta_obj(evaluated_moves::Vector{<:MoveEvaluatorOutput}) =
    delta_obj(pick_a_move(GreedyMoveSelection(), evaluated_moves))

"""
    init_neighbourhood(h::GreedyNeighbourhood, model::Model)

Initializes the greedy neighbourhood by evaluating and ordering all variables.

# Returns
Ordered vector of LazyCartesianMoves based on potential improvement

# Process
1. Evaluates each variable's potential contribution
2. Creates LazyCartesianMoves for each variable
3. Orders moves based on best potential improvement
4. Sets initialization flag

# Notes
- Uses parallel evaluation for efficiency
- Shows progress bar during initialization
- Orders variables by their best feasible delta objective
"""
function init_neighbourhood(h::GreedyNeighbourhood, model::Model)
    nb_variables = length(decision_variables(model))
    best_delta_objs = Vector{Float64}(undef, nb_variables)
    moves = Vector{LazyCartesianMoves}(undef, nb_variables)

    Threads.@threads for variable_id = 1:nb_variables
        best_delta_objs[variable_id] = best_feasible_delta_obj(eval_variable(variable_id, model))

        moves[variable_id] = LazyCartesianMoves(decision_variables(model)[[variable_id]])
    end
    h._is_init = true
    perm = sortperm(best_delta_objs)
    return moves[perm]
end

_default_mask(h::GreedyNeighbourhood, model::Model) = trues(length(decision_variables(model)))

@testitem "get_neighbourhood(::GreedyNeighbourhood)" begin
    using Dates
    using Random

    e = JuLS.KnapsackExperiment(JuLS.PROJECT_ROOT * "/data/knapsack/ks_4_0")
    model = JuLS.init_model(e; neigh = JuLS.GreedyNeighbourhood())

    rng = MersenneTwister(0)
    move = JuLS.get_neighbourhood(JuLS.neighbourhood_heuristic(model), model; rng)
    @test typeof(move) == JuLS.LazyCartesianMoves
    @test length(JuLS.neighbourhood_heuristic(model).queue) == 3
    move2 = JuLS.get_neighbourhood(JuLS.neighbourhood_heuristic(model), model; rng)
    @test typeof(move2) == JuLS.LazyCartesianMoves
    @test length(JuLS.neighbourhood_heuristic(model).queue) == 2
    move3 = JuLS.get_neighbourhood(JuLS.neighbourhood_heuristic(model), model; rng)
    @test typeof(move3) == JuLS.LazyCartesianMoves
    @test length(JuLS.neighbourhood_heuristic(model).queue) == 1
    move4 = JuLS.get_neighbourhood(JuLS.neighbourhood_heuristic(model), model; rng)
    @test typeof(move4) == JuLS.LazyCartesianMoves
    move5 = JuLS.get_neighbourhood(JuLS.neighbourhood_heuristic(model), model; rng)
    @test length(JuLS.neighbourhood_heuristic(model).queue) == 0
    @test move5[1] == JuLS.NO_MOVE
    @test typeof(move5) == Vector{JuLS.Move}
    @test length(JuLS.neighbourhood_heuristic(model).queue) == 0
    JuLS.optimize!(model; limit = JuLS.IterationLimit(1))
end

@testitem "init_neighbourhood(::GreedyNeighbourhood)" begin
    using Dates
    using Random
    using Base.Threads

    e = JuLS.KnapsackExperiment(JuLS.PROJECT_ROOT * "/data/knapsack/ks_19_0")
    model = JuLS.init_model(e; neigh = JuLS.GreedyNeighbourhood())

    @test length(JuLS.neighbourhood_heuristic(model).queue) == 0
    @test JuLS.neighbourhood_heuristic(model)._is_init == false
    moves = JuLS.init_neighbourhood(JuLS.neighbourhood_heuristic(model), model)
    @test JuLS.neighbourhood_heuristic(model)._is_init == true
    @test typeof(moves) == Vector{JuLS.LazyCartesianMoves}
    @test JuLS.delta_obj(JuLS.eval(model.dag, moves[1][1])) <= JuLS.delta_obj(JuLS.eval(model.dag, moves[2][1]))
end

@testitem "eval_variable()" begin
    using Dates
    using Random

    e = JuLS.KnapsackExperiment(JuLS.PROJECT_ROOT * "/data/knapsack/ks_19_0")
    model = JuLS.init_model(e; neigh = JuLS.GreedyNeighbourhood())

    @test [length(JuLS.eval_variable(variable_id, model)) for variable_id = 1:3] == [2, 2, 2]

    @test all([typeof(x) <: JuLS.MoveEvaluatorOutput for x in JuLS.eval_variable(1, model)])
end

@testitem "best_feasible_delta_obj()" begin
    using Dates
    using Random

    e = JuLS.KnapsackExperiment(JuLS.PROJECT_ROOT * "/data/knapsack/ks_19_0")
    model = JuLS.init_model(e; neigh = JuLS.GreedyNeighbourhood())

    variable_id = 1
    evaluated_moves = JuLS.eval_variable(variable_id, model)
    filtered_moves = filter(x -> JuLS.isfeasible(x), evaluated_moves)
    @test all([JuLS.isfeasible(x) for x in filtered_moves] == [true for x in filtered_moves])

    best_delta_obj = JuLS.best_feasible_delta_obj(evaluated_moves)
    @test typeof(best_delta_obj) == Float64
    @test all([best_delta_obj <= JuLS.delta_obj(x) for x in filtered_moves])
    @test JuLS.best_feasible_delta_obj(JuLS.MoveEvaluatorOutput[]) == 0
end
