# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    BinaryRandomNeighbourhood <: NeighbourhoodHeuristic

A neighbourhood generation strategy for binary optimization problems that randomly selects and flips variables.

# Fields
- `number_of_moves::Int`: Number of moves to generate in each neighbourhood
- `number_of_variables_to_move::Int`: Number of variables to flip in each move

# Description
Generates moves by randomly selecting a specified number of binary variables
and flipping their values (0->1 or 1->0) in each move. This creates a
neighbourhood of potential solutions around the current solution.
"""
struct BinaryRandomNeighbourhood <: NeighbourhoodHeuristic
    number_of_moves::Int
    number_of_variables_to_move::Int
end
_default_mask(::BinaryRandomNeighbourhood, m::AbstractModel) = trues(length(decision_variables(m)))

"""
    get_neighbourhood(
        h::BinaryRandomNeighbourhood,
        model::Model;
        rng = Random.GLOBAL_RNG,
        mask::BitVector = _default_mask(h, model)
    )

Generates a neighbourhood of random binary moves.

# Process
1. Applies mask to get valid variables for modification
2. Generates specified number of moves by randomly selecting and flipping variables
3. Each move flips the specified number of variables
"""
function get_neighbourhood(
    h::BinaryRandomNeighbourhood,
    model::Model;
    rng = Random.GLOBAL_RNG,
    mask::BitVector = _default_mask(h, model),
)
    variables_view = decision_variables(model)[mask]

    return [_get_one_move(h, variables_view; rng) for _ = 1:h.number_of_moves]
end

function _get_one_move(h::BinaryRandomNeighbourhood, variables::Array{DecisionVariable}; rng = Random.GLOBAL_RNG)
    selected_variables = sample(rng, variables, h.number_of_variables_to_move; replace = false)

    return Move(selected_variables, [BinaryDecisionValue(!current_value(var).value) for var in selected_variables])
end

@testitem "_get_one_move(::BinaryRandomNeighbourhood)" begin
    using Random
    heuristic = JuLS.BinaryRandomNeighbourhood(3, 2)

    var1 = JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(true))
    var2 = JuLS.DecisionVariable(2, JuLS.BinaryDecisionValue(true))
    var3 = JuLS.DecisionVariable(3, JuLS.BinaryDecisionValue(false))
    decision_variables = JuLS.DecisionVariable[var1, var2, var3]

    rng = Random.MersenneTwister(0)

    move = JuLS._get_one_move(heuristic, decision_variables)

    @test length(move.variables) == 2
    @test length(move.new_values) == 2
    @test move.variables[1].current_value.value == !move.new_values[1].value
    @test move.variables[2].current_value.value == !move.new_values[2].value
end

@testitem "get_neighbourhood(::BinaryRandomNeighbourhood)" begin
    using Random
    struct FakeDAG <: JuLS.MoveEvaluator end

    heuristic = JuLS.BinaryRandomNeighbourhood(3, 2)

    sol = JuLS.Solution(
        [JuLS.BinaryDecisionValue(true), JuLS.BinaryDecisionValue(false), JuLS.BinaryDecisionValue(false)],
        2.3,
        false,
    )
    model = JuLS.Model(heuristic, JuLS.GreedyMoveSelection(), FakeDAG(), sol)

    moves = JuLS.get_neighbourhood(model)

    @test length(moves) == 3
end
