# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    Solution

Represents a solution (or assignment) in an optimization problem.

# Fields
- `values::Array{DecisionValue}`: Assigned values of all decision variables
- `objective::Float64`: Objective value of this solution
- `feasible::Bool`: Whether the solution satisfies all constraints
"""
mutable struct Solution
    values::Array{DecisionValue}
    objective::Float64
    feasible::Bool
end


"""
    Solution(decision_variables::Array{DecisionVariable}, dag::MoveEvaluator)

Constructs a Solution by evaluating decision variables using a DAG evaluator.
"""
Solution(decision_variables::Array{DecisionVariable}, dag::MoveEvaluator) =
    Solution(eval(dag, DecisionVariablesArray(decision_variables)))
DecisionVariablesArray(solution::Solution) = DecisionVariablesArray(generate_decision_variables(solution))

"""
    apply_move!(solution::Solution, evaluated_move::MoveEvaluatorOutput)

Updates a solution in-place by applying an evaluated move.

# Effects
1. Updates the objective value using the move's delta
2. Updates the feasibility status
3. Updates the values of affected variables
"""
function apply_move!(solution::Solution, evaluated_move::MoveEvaluatorOutput)
    solution.objective += delta_obj(evaluated_move)

    solution.feasible = isfeasible(evaluated_move)

    for move_index in eachindex(move(evaluated_move).variables)
        var_index = move(evaluated_move).variables[move_index].index
        solution.values[var_index] = move(evaluated_move).new_values[move_index]
    end
end

values(s::Solution) = s.values

isfeasible(s::Solution) = s.feasible

Base.copy(s::Solution) = Solution(copy(s.values), s.objective, s.feasible)

@testitem "apply_move!(::Solution)" begin
    sol = JuLS.Solution([JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(4), JuLS.IntDecisionValue(3)], 54.23, false)

    var2 = JuLS.DecisionVariable(2, JuLS.IntDecisionValue(4))
    var3 = JuLS.DecisionVariable(3, JuLS.IntDecisionValue(3))

    move = JuLS.Move([var2, var3], [JuLS.IntDecisionValue(8), JuLS.IntDecisionValue(10)])
    evaluated_move = JuLS.EvaluatedMove(move, JuLS.ResultDelta(-4.2, true))

    JuLS.apply_move!(sol, evaluated_move)

    @test sol.values[1] == JuLS.IntDecisionValue(3)
    @test sol.values[2] == JuLS.IntDecisionValue(8)
    @test sol.values[3] == JuLS.IntDecisionValue(10)
    @test sol.objective ≈ 50.03
    @test sol.feasible
end

@testitem "copy(::Solution)" begin
    sol = JuLS.Solution(
        [JuLS.BinaryDecisionValue(true), JuLS.BinaryDecisionValue(false), JuLS.BinaryDecisionValue(false)],
        54.23,
        true,
    )

    cloned_sol = copy(sol)

    sol.values[1] = JuLS.BinaryDecisionValue(false)
    sol.feasible = false

    @test sol.values[1] == JuLS.BinaryDecisionValue(false)
    @test cloned_sol.values[1] == JuLS.BinaryDecisionValue(true)
    @test !sol.feasible
    @test cloned_sol.feasible
end