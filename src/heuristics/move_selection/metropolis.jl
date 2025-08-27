# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    Metropolis <: MoveSelectionHeuristic

# Fields
- `T::Float64`: Temperature for metropolis probability

Of all the moves given, take the best delta, return it if negative or return it with probability exp(-δ/T).
"""
struct Metropolis <: MoveSelectionHeuristic
    T::Float64
end


"""
    pick_a_move(::Metropolis, evaluated_moves::Vector{<:MoveEvaluatorOutput})

Of all the moves given, take the best delta, return it if negative or return it with probability exp(-δ/T).
"""
function pick_a_move(h::Metropolis, evaluated_moves::Vector{<:MoveEvaluatorOutput}; rng = Random.default_rng())
    best_move = pick_a_move(GreedyMoveSelection(), evaluated_moves)

    δ = delta_obj(best_move)

    δ > 0 || return best_move

    p = rand(rng)

    p > exp(-δ / h.T) || return best_move

    return DONT_MOVE
end


@testitem "pick_a_move(::Metropolis)" begin
    var1 = JuLS.DecisionVariable(1, JuLS.IntDecisionValue(8))
    var2 = JuLS.DecisionVariable(2, JuLS.IntDecisionValue(4))
    var3 = JuLS.DecisionVariable(3, JuLS.IntDecisionValue(3))
    decision_variables = JuLS.DecisionVariable[var1, var2, var3]

    move = JuLS.Move([var2, var3], [JuLS.IntDecisionValue(9), JuLS.IntDecisionValue(10)])
    evaluated_move1 = JuLS.EvaluatedMove(move, JuLS.ResultDelta(-4.2, false))
    evaluated_move2 = JuLS.EvaluatedMove(move, JuLS.ResultDelta(9.3, true))
    evaluated_move3 = JuLS.EvaluatedMove(move, JuLS.ResultDelta(-85.8, false))

    picked_move = JuLS.pick_a_move(JuLS.Metropolis(100), [evaluated_move1, evaluated_move2, evaluated_move3])

    @test isa(picked_move, JuLS.EvaluatedMove)
    @test picked_move in [evaluated_move1, evaluated_move2, evaluated_move3]
end
