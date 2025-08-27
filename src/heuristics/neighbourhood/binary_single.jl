# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    BinarySingleNeighbourhood <: NeighbourhoodHeuristic

A neighbourhood generation strategy for binary optimization problems that generates all possible moves where exactly one binary variable is flipped. 
"""
struct BinarySingleNeighbourhood <: NeighbourhoodHeuristic end
_default_mask(::BinarySingleNeighbourhood, m::AbstractModel) = trues(length(decision_variables(m)))

"""
    get_neighbourhood(::BinarySingleNeighbourhood, m::Model)

Return all the possible single moves that can be made when all the variables are binary.
For every variable, the move toggling it is put in the returned array.
"""
function get_neighbourhood(
    h::BinarySingleNeighbourhood,
    model::Model;
    rng = Random.GLOBAL_RNG,
    mask::BitVector = _default_mask(h, model),
)
    variables_view = decision_variables(model)[mask]

    moves = Array{Move,1}(undef, length(variables_view))

    for i in eachindex(variables_view)
        moves[i] = Move([variables_view[i]], [BinaryDecisionValue(!current_value(variables_view[i]).value)])
    end

    return moves
end

@testitem "get_neighbourhood(::BinarySingleNeighbourhood)" begin
    struct FakeDAG <: JuLS.MoveEvaluator end

    sol = JuLS.Solution([JuLS.BinaryDecisionValue(true), JuLS.BinaryDecisionValue(false)], 2.3, false)
    model = JuLS.Model(JuLS.BinarySingleNeighbourhood(), JuLS.GreedyMoveSelection(), FakeDAG(), sol)

    moves = JuLS.get_neighbourhood(model)

    @test length(moves) == 2
    @test length(moves[1].variables) == 1
    @test moves[1].variables[1] == model.decision_variables[1]
    @test length(moves[1].new_values) == 1
    @test moves[1].new_values[1] == JuLS.BinaryDecisionValue(false)
    @test length(moves[2].variables) == 1
    @test moves[2].variables[1] == model.decision_variables[2]
    @test length(moves[2].new_values) == 1
    @test moves[2].new_values[1] == JuLS.BinaryDecisionValue(true)
end