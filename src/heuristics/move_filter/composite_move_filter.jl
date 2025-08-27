# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    CompositeMoveFilter <: AbstractMoveFilter

A composite filter that applies multiple move filters sequentially.

# Fields
- `move_filters::Vector{AbstractMoveFilter}`: An ordered list of move filters to be applied
"""
struct CompositeMoveFilter <: AbstractMoveFilter
    move_filters::Vector{AbstractMoveFilter}
end

function filter_moves(
    model::AbstractModel,
    composite::CompositeMoveFilter,
    moves::AbstractArray{<:MoveEvaluatorInput,1},
    rng = Random.GLOBAL_RNG,
)
    filtered_moves = moves
    for filter in composite.move_filters
        filtered_moves = filter_moves(model, filter, filtered_moves, rng)
    end
    return filtered_moves
end

@testitem "filter_moves(::CompositeMoveFilter)" begin
    struct DummyModel <: JuLS.AbstractModel end

    using Random
    rng = MersenneTwister(0)

    move_filter1 = JuLS.RandomMoveSampler(5)
    move_filter2 = JuLS.RandomMoveSampler(3)
    composite = JuLS.CompositeMoveFilter([move_filter1, move_filter2])

    domain = [JuLS.IntDecisionValue(i) for i = 1:7]
    moves = JuLS.LazyCartesianMoves(
        JuLS.DecisionVariable[
            JuLS.DecisionVariable(1, domain[1:4], JuLS.IntDecisionValue(2)),
            JuLS.DecisionVariable(2, domain[1:3], JuLS.IntDecisionValue(1)),
            JuLS.DecisionVariable(3, domain[1:7], JuLS.IntDecisionValue(4)),
        ],
    )

    sampled_moves = JuLS.filter_moves(DummyModel(), composite, moves, rng)

    @test length(sampled_moves) == 4
    @test sampled_moves[1].new_values == [JuLS.IntDecisionValue(1), JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(4)]
    @test sampled_moves[2].new_values == [JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(1), JuLS.IntDecisionValue(6)]
    @test sampled_moves[3].new_values == [JuLS.IntDecisionValue(1), JuLS.IntDecisionValue(1), JuLS.IntDecisionValue(4)]
    @test sampled_moves[4] == JuLS.NO_MOVE
end