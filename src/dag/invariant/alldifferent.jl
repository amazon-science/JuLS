# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct AllDifferentInvariant <: Invariant

An invariant that enforces all variables to have different values.

# Description
Represents the constraint x₁ ≠ x₂ ≠ ... ≠ xₙ where each variable xᵢ takes values 
in the domain D = {1,...,n}.

# Violation Measure
The violation is calculated as:
    y = ∑ max(0, c(i) - 1)
where c(i) is the count of variables taking value i.

# Fields
- `current_value_counter::Vector{Int}`: Counts occurrences of each value in the current assignment

# Constructor
    AllDifferentInvariant(n_variables::Int)

Creates an AllDifferentInvariant for n_variables variables, initializing the counter to zeros.
"""
mutable struct AllDifferentInvariant <: Invariant
    current_value_counter::Vector{Int}
end
AllDifferentInvariant(n_variables::Int) = AllDifferentInvariant(zeros(Int, n_variables))
n_variables(invariant::AllDifferentInvariant) = length(invariant.current_value_counter)

function init!(invariant::AllDifferentInvariant, messages::DAGMessagesVector{SingleVariableMessage{IntDecisionValue}})
    n = length(invariant.current_value_counter)
    @assert length(messages) == n
    invariant.current_value_counter .= 0
    for m in messages
        val = m.value.value
        if val < 1 || val > n
            error("All the values must be between 1 and $n")
        end
        invariant.current_value_counter[val] += 1
    end
    violation = sum(max(0, invariant.current_value_counter[i] - 1) for i = 1:n)
    return FloatFullMessage(violation)
end

function eval(invariant::AllDifferentInvariant, messages::DAGMessagesVector{SingleVariableMessage{IntDecisionValue}})
    values = Set{Int}()
    for m in messages
        union!(values, m.value.value)
    end
    return FloatFullMessage(n_variables(invariant) - length(values))
end

function eval(invariant::AllDifferentInvariant, deltas::DAGMessagesVector{SingleVariableMoveDelta{IntDecisionValue}})
    new_counter = copy(invariant.current_value_counter)
    impacted_values = Set{Int}()
    for δ in deltas
        new_counter[δ.current_value.value] -= 1
        new_counter[δ.new_value.value] += 1
        union!(impacted_values, [δ.current_value.value, δ.new_value.value])
    end
    violation_delta = 0
    for value in impacted_values
        violation_delta += max(0, new_counter[value] - 1) - max(0, invariant.current_value_counter[value] - 1)
    end
    return FloatDelta(violation_delta)
end

function commit!(invariant::AllDifferentInvariant, deltas::DAGMessagesVector{SingleVariableMoveDelta{IntDecisionValue}})
    for δ in deltas
        invariant.current_value_counter[δ.current_value.value] -= 1
        invariant.current_value_counter[δ.new_value.value] += 1
    end
end

@testitem "init!(::AllDifferentInvariant)" begin
    n = 10
    invariant = JuLS.AllDifferentInvariant(n)

    messages = JuLS.DAGMessagesVector([JuLS.SingleVariableMessage(i, i) for i = 1:n])
    @test JuLS.init!(invariant, messages) == JuLS.FloatFullMessage(0)

    for i = 1:n
        @test invariant.current_value_counter[i] == 1
    end

    messages = JuLS.DAGMessagesVector([JuLS.SingleVariableMessage(i, 1) for i = 1:n])
    @test JuLS.init!(invariant, messages) == JuLS.FloatFullMessage(9)

    @test invariant.current_value_counter[1] == 10
    for i = 2:n
        invariant.current_value_counter[i] == 0
    end
end

@testitem "eval(::AllDifferentInvariant, ::FullMessage)" begin
    n = 10
    invariant = JuLS.AllDifferentInvariant(n)

    messages = JuLS.DAGMessagesVector([JuLS.SingleVariableMessage(i, i) for i = 1:n])
    @test JuLS.eval(invariant, messages) == JuLS.FloatFullMessage(0)

    messages = JuLS.DAGMessagesVector([JuLS.SingleVariableMessage(i, 1) for i = 1:n])
    @test JuLS.eval(invariant, messages) == JuLS.FloatFullMessage(9)
end

@testitem "eval(::AllDifferentInvariant, ::Delta)" begin
    n = 10
    invariant = JuLS.AllDifferentInvariant(n)

    # Starting from a feasible state
    messages = JuLS.DAGMessagesVector([JuLS.SingleVariableMessage(i, i) for i = 1:n])
    JuLS.init!(invariant, messages)

    deltas1 = JuLS.DAGMessagesVector([
        JuLS.SingleVariableMoveDelta(1, 1, 4),
        JuLS.SingleVariableMoveDelta(4, 4, 7),
        JuLS.SingleVariableMoveDelta(7, 7, 1),
    ])

    @test JuLS.eval(invariant, deltas1) == JuLS.FloatDelta(0)

    deltas2 = JuLS.DAGMessagesVector([JuLS.SingleVariableMoveDelta(1, 1, 4), JuLS.SingleVariableMoveDelta(3, 3, 7)])

    @test JuLS.eval(invariant, deltas2) == JuLS.FloatDelta(2)

    # Starting from an infeasible state
    messages = JuLS.DAGMessagesVector([JuLS.SingleVariableMessage(i, 1) for i = 1:n])
    JuLS.init!(invariant, messages)

    deltas3 = JuLS.DAGMessagesVector([JuLS.SingleVariableMoveDelta(i, 1, i) for i = 2:n])

    @test JuLS.eval(invariant, deltas3) == JuLS.FloatDelta(-9)

    deltas4 = JuLS.DAGMessagesVector([
        JuLS.SingleVariableMoveDelta(1, 1, 4),
        JuLS.SingleVariableMoveDelta(3, 1, 7),
        JuLS.SingleVariableMoveDelta(5, 1, 7),
        JuLS.SingleVariableMoveDelta(8, 1, 2),
    ])
    @test JuLS.eval(invariant, deltas4) == JuLS.FloatDelta(-3)
end

@testitem "commit!(::AllDifferentInvariant)" begin
    n = 10
    invariant = JuLS.AllDifferentInvariant(n)

    # Starting from a feasible state
    messages = JuLS.DAGMessagesVector([JuLS.SingleVariableMessage(i, i) for i = 1:n])
    JuLS.init!(invariant, messages)

    deltas1 = JuLS.DAGMessagesVector([
        JuLS.SingleVariableMoveDelta(1, 1, 4),
        JuLS.SingleVariableMoveDelta(4, 4, 7),
        JuLS.SingleVariableMoveDelta(7, 7, 1),
    ])
    JuLS.commit!(invariant, deltas1)

    @test invariant.current_value_counter == ones(Int, n)

    deltas2 = JuLS.DAGMessagesVector([JuLS.SingleVariableMoveDelta(1, 1, 4), JuLS.SingleVariableMoveDelta(3, 3, 7)])
    JuLS.commit!(invariant, deltas2)

    @test invariant.current_value_counter == [0, 1, 0, 2, 1, 1, 2, 1, 1, 1]

    # Starting from an infeasible state
    messages = JuLS.DAGMessagesVector([JuLS.SingleVariableMessage(i, 1) for i = 1:n])
    JuLS.init!(invariant, messages)

    deltas3 = JuLS.DAGMessagesVector([JuLS.SingleVariableMoveDelta(i, 1, i) for i = 2:n])
    JuLS.commit!(invariant, deltas3)

    @test invariant.current_value_counter == ones(Int, n)

    JuLS.init!(invariant, messages)

    deltas4 = JuLS.DAGMessagesVector([
        JuLS.SingleVariableMoveDelta(1, 1, 4),
        JuLS.SingleVariableMoveDelta(3, 1, 7),
        JuLS.SingleVariableMoveDelta(5, 1, 7),
        JuLS.SingleVariableMoveDelta(8, 1, 2),
    ])
    JuLS.commit!(invariant, deltas4)

    @test invariant.current_value_counter == [6, 1, 0, 1, 0, 0, 2, 0, 0, 0]
end