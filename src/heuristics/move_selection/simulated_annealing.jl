# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    Metropolis <: MoveSelectionHeuristic

# Fields
-`T::Float64`: Temperature
-`α::Float64`: Cooling factor
-`T_min::Float64` : Minimal temperature

Of all the moves given, take the best delta, return it if negative or return it with probability exp(-δ/T).
"""
mutable struct SimulatedAnnealing <: MoveSelectionHeuristic
    T::Float64
    α::Float64
    T_min::Float64
end
SimulatedAnnealing(T::Float64, α::Float64) = SimulatedAnnealing(T, α, 0.0)
SimulatedAnnealing(T::Float64) = SimulatedAnnealing(T, 0.99)
SimulatedAnnealing() = SimulatedAnnealing(1.0)

"""
    pick_a_move(::SimulatedAnnealing, evaluated_moves::Vector{<:MoveEvaluatorOutput})

Of all the moves given, pick a move based on metropolis heuristic, then update the temperature.
"""
function pick_a_move(h::SimulatedAnnealing, evaluated_moves::Vector{<:MoveEvaluatorOutput}; rng = Random.default_rng())
    move = pick_a_move(Metropolis(h.T), evaluated_moves; rng)
    h.T = max(h.α * h.T, h.T_min)
    return move
end

@testitem "Constructor" begin
    h = JuLS.SimulatedAnnealing()

    @test h.T == 1
    @test h.α == 0.99
end


@testitem "pick_a_move(::SimulatedAnnealing)" begin
    var1 = JuLS.DecisionVariable(1, JuLS.IntDecisionValue(8))
    var2 = JuLS.DecisionVariable(2, JuLS.IntDecisionValue(4))
    var3 = JuLS.DecisionVariable(3, JuLS.IntDecisionValue(3))
    decision_variables = JuLS.DecisionVariable[var1, var2, var3]

    move = JuLS.Move([var2, var3], [JuLS.IntDecisionValue(9), JuLS.IntDecisionValue(10)])
    evaluated_move1 = JuLS.EvaluatedMove(move, JuLS.ResultDelta(-4.2, false))
    evaluated_move2 = JuLS.EvaluatedMove(move, JuLS.ResultDelta(9.3, true))
    evaluated_move3 = JuLS.EvaluatedMove(move, JuLS.ResultDelta(-85.8, false))

    h = JuLS.SimulatedAnnealing(5.1, 0.9)

    for i = 1:3
        picked_move = JuLS.pick_a_move(h, [evaluated_move1, evaluated_move2, evaluated_move3])

        @test picked_move in [evaluated_move1, evaluated_move2, evaluated_move3]
        @test h.T == 5.1 * (0.9^i)
    end

end