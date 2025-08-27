# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    Move <: MoveEvaluatorInput

Represents a potential change in decision variables' values in an optimization problem.

# Fields
- `variables::Vector{DecisionVariable}`: Variables that would be modified by this move
- `new_values::Vector`: New values to assign to the variables
"""
struct Move <: MoveEvaluatorInput
    variables::Vector{DecisionVariable}
    new_values::Vector
end


"""
    Base.:*(move1::Move, move2::Move)

Combines two moves into a single move, handling potential variable overlaps.

# Arguments
- `move1::Move`: First move to combine
- `move2::Move`: Second move to combine

# Returns
A new Move that combines both input moves, with move2's values taking precedence for overlapping variables.

# Notes
- Non-commutative operation: move1 * move2 ≠ move2 * move1
- For duplicate variables, keeps current value from move1 and new value from move2
"""
function Base.:*(move1::Move, move2::Move)
    variables_array = reverse(vcat(move1.variables, move2.variables)) # move2 will override move1 if the same index appears twice
    new_values_array = reverse(vcat(move1.new_values, move2.new_values))

    new_move = Move(Vector{DecisionVariable}(), Vector{DecisionValue}())

    visited_indexes = Set{Int}()

    for index in eachindex(variables_array)
        visited_index = variables_array[index].index

        if visited_index ∈ visited_indexes
            index_in_move = findfirst(x -> x.index == visited_index, new_move.variables)
            change_value!(new_move.variables[index_in_move], variables_array[index].current_value)
            continue
        end

        push!(new_move.variables, deepcopy(variables_array[index])) # We need a copy here because we might update it
        push!(new_move.new_values, new_values_array[index])
        push!(visited_indexes, visited_index)
    end

    return new_move
end

"""
    EvaluatedMove <: MoveEvaluatorOutput

Represents a move that has been evaluated for its impact on the solution.

# Fields
- `move::Move`: The original move being evaluated
- `delta::Delta`: The calculated impact of applying this move
"""
struct EvaluatedMove <: MoveEvaluatorOutput
    move::Move
    delta::Delta
end

MoveEvaluatorOutput(m::EvaluatedMove) = m

delta(m::EvaluatedMove) = m.delta
delta_obj(m::EvaluatedMove) = delta(m).objective_delta
isfeasible(m::EvaluatedMove) = delta(m).isfeasible
isearlystop(m::EvaluatedMove) = isinf(delta_obj(m))
move(m::EvaluatedMove) = m.move


"""
    apply_move!(v::Array{DecisionVariable}, evaluated_move::Union{EvaluatedMove, Move})
    apply_move!(decision_variables::Array{DecisionVariable}, move::Move)

Applies a move by updating the current values of the affected decision variables.
"""
apply_move!(v::Array{DecisionVariable}, evaluated_move::MoveEvaluatorOutput) = apply_move!(v, move(evaluated_move))
function apply_move!(decision_variables::Array{DecisionVariable}, move::Move)
    for move_index in eachindex(move.variables)
        var_index = move.variables[move_index].index
        change_value!(decision_variables[var_index], move.new_values[move_index])
    end
end

"""
    change_value!(var::DecisionVariable{T}, val::T) where {T<:DecisionValue}

Updates the current value of a decision variable.
"""
function change_value!(var::DecisionVariable{T}, val::T) where {T<:DecisionValue}
    var.current_value = val
end

current_value(v::DecisionVariable) = v.current_value

impacted_variables(m::Move) = m.variables


@testitem "basic methods for EvaluatedMove" begin
    move = JuLS.Move([], [])
    m = JuLS.EvaluatedMove(move, JuLS.ResultDelta(10, true))

    @test JuLS.MoveEvaluatorOutput(m) == m
    @test JuLS.delta(m) == JuLS.ResultDelta(10, true)
    @test JuLS.delta_obj(m) == 10
    @test JuLS.move(m) == move
    @test JuLS.isfeasible(m)
    @test !JuLS.isearlystop(m)

    # Shouldn't happen
    m = JuLS.EvaluatedMove(move, JuLS.ResultDelta(Inf, true))

    @test JuLS.isfeasible(m)
    @test JuLS.isearlystop(m)

    m = JuLS.EvaluatedMove(move, JuLS.ResultDelta(Inf, false))

    @test !JuLS.isfeasible(m)
    @test JuLS.isearlystop(m)
end

@testitem "apply_move!(::Array{DecisionVariable}, ::Move)" begin
    sol = JuLS.Solution([JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(4), JuLS.IntDecisionValue(3)], 54.23, false)

    var1 = JuLS.DecisionVariable(1, JuLS.IntDecisionValue(8))
    var2 = JuLS.DecisionVariable(2, JuLS.IntDecisionValue(4))
    var3 = JuLS.DecisionVariable(3, JuLS.IntDecisionValue(3))
    decision_variables = JuLS.DecisionVariable[var1, var2, var3]

    move = JuLS.Move([var2, var3], [JuLS.IntDecisionValue(9), JuLS.IntDecisionValue(10)])

    JuLS.apply_move!(decision_variables, move)

    @test JuLS.current_value(var1) == JuLS.IntDecisionValue(8)
    @test JuLS.current_value(var2) == JuLS.IntDecisionValue(9)
    @test JuLS.current_value(var3) == JuLS.IntDecisionValue(10)
end

@testitem "apply_move!(::Array{DecisionVariable}, ::EvaluatedMove)" begin
    sol = JuLS.Solution([JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(4), JuLS.IntDecisionValue(3)], 54.23, false)

    var1 = JuLS.DecisionVariable(1, JuLS.IntDecisionValue(8))
    var2 = JuLS.DecisionVariable(2, JuLS.IntDecisionValue(4))
    var3 = JuLS.DecisionVariable(3, JuLS.IntDecisionValue(3))
    decision_variables = JuLS.DecisionVariable[var1, var2, var3]

    move = JuLS.Move([var2, var3], [JuLS.IntDecisionValue(9), JuLS.IntDecisionValue(10)])
    evaluated_move = JuLS.EvaluatedMove(move, JuLS.ResultDelta(-4.2, true))

    JuLS.apply_move!(decision_variables, evaluated_move)

    @test JuLS.current_value(var1) == JuLS.IntDecisionValue(8)
    @test JuLS.current_value(var2) == JuLS.IntDecisionValue(9)
    @test JuLS.current_value(var3) == JuLS.IntDecisionValue(10)
end

@testitem "*(move1, move2)" begin
    var1 = JuLS.DecisionVariable(1, JuLS.IntDecisionValue(7))
    var2 = JuLS.DecisionVariable(2, JuLS.IntDecisionValue(4))
    var3 = JuLS.DecisionVariable(3, JuLS.IntDecisionValue(3))
    var4 = JuLS.DecisionVariable(1, JuLS.IntDecisionValue(8))
    decision_variables = JuLS.DecisionVariable[var1, var2, var3]

    move1 = JuLS.Move([var1, var2], [JuLS.IntDecisionValue(10), JuLS.IntDecisionValue(4)])
    move2 = JuLS.Move([var3], [JuLS.IntDecisionValue(11)])
    move3 = JuLS.Move([var4], [JuLS.IntDecisionValue(9)])
    move4 = JuLS.Move([var3, var4], [JuLS.IntDecisionValue(100), JuLS.IntDecisionValue(102)])

    # Genersting new pointer
    @test (move1 * JuLS.NO_MOVE) != move1
    @test (JuLS.NO_MOVE * move1) != move1

    first_case = move1 * move2
    second_case = move1 * move3
    third_case = move1 * move4

    @test length(first_case.variables) == 3
    @test first_case.variables[1].index == 3
    @test first_case.variables[1].current_value == JuLS.IntDecisionValue(3)
    @test first_case.variables[2].index == 2
    @test first_case.variables[2].current_value == JuLS.IntDecisionValue(4)
    @test first_case.variables[3].index == 1
    @test first_case.variables[3].current_value == JuLS.IntDecisionValue(7)
    @test all(
        first_case.new_values .== [JuLS.IntDecisionValue(11), JuLS.IntDecisionValue(4), JuLS.IntDecisionValue(10)],
    )

    @test length(second_case.variables) == 2
    @test second_case.variables[1].index == 1
    @test second_case.variables[1].current_value == JuLS.IntDecisionValue(7)
    @test second_case.variables[2].index == 2
    @test second_case.variables[2].current_value == JuLS.IntDecisionValue(4)
    @test all(second_case.new_values .== [JuLS.IntDecisionValue(9), JuLS.IntDecisionValue(4)])

    @test length(third_case.variables) == 3
    @test third_case.variables[1].index == 1
    @test third_case.variables[1].current_value == JuLS.IntDecisionValue(7)
    @test third_case.variables[2].index == 3
    @test third_case.variables[2].current_value == JuLS.IntDecisionValue(3)
    @test third_case.variables[3].index == 2
    @test third_case.variables[3].current_value == JuLS.IntDecisionValue(4)
    @test all(
        third_case.new_values .== [JuLS.IntDecisionValue(102), JuLS.IntDecisionValue(100), JuLS.IntDecisionValue(4)],
    )
end