# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    RandomMoveSampler <: AbstractMoveFilter

A move filter that randomly samples a fixed-size subset of moves from the complete set of potential moves. 

# Fields
- `n_samples::Int`: Maximum number of moves to sample from the input set
"""
struct RandomMoveSampler <: AbstractMoveFilter
    n_samples::Int
end

function filter_moves(
    ::AbstractModel,
    filter::RandomMoveSampler,
    moves::AbstractArray{<:MoveEvaluatorInput,1},
    rng = Random.GLOBAL_RNG,
)
    if length(moves) <= filter.n_samples
        return moves
    end
    return sample_moves(moves, filter.n_samples, rng)
end

sample_moves(moves::LazyFilteredMoves, n_samples::Int, rng = Random.GLOBAL_RNG) =
    LazyFilteredMoves(moves.selected_variables, sample(rng, moves.filtered_values, n_samples, replace = false))

sample_moves(moves::LazyCartesianMoves, n_samples::Int, rng = Random.GLOBAL_RNG) = LazyFilteredMoves(
    moves.selected_variables,
    [moves[idx].new_values for idx in sample(rng, collect(1:length(moves)-1), n_samples, replace = false)],
)

sample_moves(moves::Vector{Move}, n_samples::Int, rng = Random.GLOBAL_RNG) =
    sample(rng, moves, n_samples, replace = false)

@testitem "filter_moves(::RandomMoveSampler)" begin
    using Random
    rng = MersenneTwister(0)

    struct DummyModel <: JuLS.AbstractModel end

    filter = JuLS.RandomMoveSampler(3)

    domain = [JuLS.IntDecisionValue(i) for i = 1:7]
    moves = JuLS.LazyCartesianMoves(
        JuLS.DecisionVariable[
            JuLS.DecisionVariable(1, domain[1:4], JuLS.IntDecisionValue(2)),
            JuLS.DecisionVariable(2, domain[1:3], JuLS.IntDecisionValue(1)),
            JuLS.DecisionVariable(3, domain[1:7], JuLS.IntDecisionValue(4)),
        ],
    )

    sampled_moves = JuLS.filter_moves(DummyModel(), filter, moves, rng)

    @test length(sampled_moves) == 3 + 1
    @test sampled_moves[1].new_values ==
          JuLS.IntDecisionValue[JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(1)]
    @test sampled_moves[2].new_values ==
          JuLS.IntDecisionValue[JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(1), JuLS.IntDecisionValue(6)]
    @test sampled_moves[3].new_values ==
          JuLS.IntDecisionValue[JuLS.IntDecisionValue(4), JuLS.IntDecisionValue(2), JuLS.IntDecisionValue(4)]
    @test sampled_moves[4].new_values == JuLS.IntDecisionValue[]

    moves = JuLS.LazyFilteredMoves(
        [
            JuLS.DecisionVariable(1, JuLS.IntDecisionValue(2)),
            JuLS.DecisionVariable(2, JuLS.IntDecisionValue(1)),
            JuLS.DecisionVariable(3, JuLS.IntDecisionValue(4)),
        ],
        [JuLS.DecisionValue.([2, 1, 4]), JuLS.DecisionValue.([3, 2, 6])],
    )
    sampled_moves = JuLS.filter_moves(DummyModel(), filter, moves, rng)

    @test length(sampled_moves) == length(moves)
end