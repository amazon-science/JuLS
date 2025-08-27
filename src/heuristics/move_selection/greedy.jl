# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    GreedyMoveSelection <: MoveSelectionHeuristic

Greedy move selection heuristic. Always pick the most impactful move.
"""
struct GreedyMoveSelection <: MoveSelectionHeuristic end

"""
    pick_a_move(::GreedyMoveSelection, evaluated_moves::Vector{<:MoveEvaluatorOutput})

Of all the evaluated moves given, always return the one that decreases the objective the most.
"""
function pick_a_move(::GreedyMoveSelection, evaluated_moves::Vector{<:MoveEvaluatorOutput}; rng = Random.GLOBAL_RNG)
    isempty(evaluated_moves) && return DONT_MOVE
    move_index = argmin([delta_obj(m) for m in evaluated_moves])
    isinf(delta_obj(evaluated_moves[move_index])) && return DONT_MOVE
    return evaluated_moves[move_index]
end

@testitem "pick_a_move(::GreedyMoveSelection)" begin
    var1 = JuLS.DecisionVariable(1, JuLS.IntDecisionValue(8))
    var2 = JuLS.DecisionVariable(2, JuLS.IntDecisionValue(4))
    var3 = JuLS.DecisionVariable(3, JuLS.IntDecisionValue(3))
    decision_variables = JuLS.DecisionVariable[var1, var2, var3]

    move = JuLS.Move([var2, var3], [JuLS.IntDecisionValue(9), JuLS.IntDecisionValue(10)])
    evaluated_move1 = JuLS.EvaluatedMove(move, JuLS.ResultDelta(-4.2, false))
    evaluated_move2 = JuLS.EvaluatedMove(move, JuLS.ResultDelta(9.3, true))
    evaluated_move3 = JuLS.EvaluatedMove(move, JuLS.ResultDelta(-85.8, false))

    @test JuLS.pick_a_move(JuLS.GreedyMoveSelection(), [evaluated_move1, evaluated_move2, evaluated_move3]) ==
          evaluated_move3
    @test JuLS.pick_a_move(JuLS.GreedyMoveSelection(), JuLS.MoveEvaluatorOutput[]) == JuLS.DONT_MOVE
end

@testitem "pick_a_move(::GreedyMoveSelection) infinite" begin
    var1 = JuLS.DecisionVariable(1, JuLS.IntDecisionValue(8))
    var2 = JuLS.DecisionVariable(2, JuLS.IntDecisionValue(4))
    var3 = JuLS.DecisionVariable(3, JuLS.IntDecisionValue(3))
    decision_variables = JuLS.DecisionVariable[var1, var2, var3]

    move = JuLS.Move([var2, var3], [JuLS.IntDecisionValue(9), JuLS.IntDecisionValue(10)])
    evaluated_move1 = JuLS.EvaluatedMove(move, JuLS.ResultDelta(Inf, false))
    evaluated_move2 = JuLS.EvaluatedMove(move, JuLS.ResultDelta(Inf, true))
    evaluated_move3 = JuLS.EvaluatedMove(move, JuLS.ResultDelta(Inf, false))
    evaluated_move4 = JuLS.EvaluatedMove(move, JuLS.ResultDelta(1.0, false))

    @test JuLS.pick_a_move(JuLS.GreedyMoveSelection(), [evaluated_move1, evaluated_move2, evaluated_move3]) ==
          JuLS.DONT_MOVE

    @test JuLS.pick_a_move(JuLS.GreedyMoveSelection(), [evaluated_move4, evaluated_move2, evaluated_move3]) ==
          evaluated_move4

end