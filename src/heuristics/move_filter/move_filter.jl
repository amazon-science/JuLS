# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    filter_moves(model::AbstractModel, 
                 moves::AbstractArray{<:MoveEvaluatorInput,1}, 
                 rng = Random.GLOBAL_RNG)

Apply the model's move filter to a set of potential moves.
"""
filter_moves(model::AbstractModel, moves::AbstractArray{<:MoveEvaluatorInput,1}, rng = Random.GLOBAL_RNG) =
    filter_moves(model, move_filter(model), moves, rng)

filter_moves(
    ::AbstractModel,
    ::AbstractMoveFilter,
    moves::AbstractArray{<:MoveEvaluatorInput,1},
    rng = Random.GLOBAL_RNG,
) = moves

"""
    LazyFilteredMoves <: AbstractArray{SetMove,1}

Array of Move filtered by a MoveFilter. This structure always stores an additional move which is NO_MOVE
"""
struct LazyFilteredMoves <: AbstractArray{Move,1}
    selected_variables::Vector{DecisionVariable}
    filtered_values::Vector{Vector{DecisionValue}}
end
Base.size(moves::LazyFilteredMoves) = (length(moves.filtered_values) + 1,)

Base.IndexStyle(::LazyFilteredMoves) = IndexLinear()
function Base.getindex(moves::LazyFilteredMoves, i::Int)
    if i == length(moves)
        return JuLS.NO_MOVE
    end
    return Move(moves.selected_variables, moves.filtered_values[i])
end

include("random_sampler.jl")
include("cp_enumeration.jl")
include("composite_move_filter.jl")

function create_move_filter(move_filters::Vector{AbstractMoveFilter})
    move_filters = filter(f -> !(f isa DummyMoveFilter), move_filters)
    if isempty(move_filters)
        return DummyMoveFilter()
    end
    if length(move_filters) == 1
        return move_filters[1]
    end
    return CompositeMoveFilter(move_filters)
end

@testitem "create_move_filter()" begin
    f1 = JuLS.DummyMoveFilter()
    f2 = JuLS.RandomMoveSampler(3)

    @test JuLS.create_move_filter(JuLS.AbstractMoveFilter[f1, f2, f1]) == f2
    @test JuLS.create_move_filter(JuLS.AbstractMoveFilter[f2]) == f2
    @test JuLS.create_move_filter(JuLS.AbstractMoveFilter[f2, f2]) isa JuLS.CompositeMoveFilter
    @test JuLS.create_move_filter(JuLS.AbstractMoveFilter[f2, f2]).move_filters == [f2, f2]
end