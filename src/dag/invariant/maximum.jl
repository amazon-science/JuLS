# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    MaximumInvariant <: Invariant

Invariant representing the maximum value among its input variables for strictly positive variables 
Basically y = max(x_1, x_2, ..., x_n) with x_i > 0

# Fields
- `current_value_counter::Vector{Int}`: A vector counting the occurrences of each possible value.
- `current_max::Int`: The current maximum value.

# Constructor
    MaximumInvariant(max_value::Int)

Constructs a `MaximumInvariant` with a given maximum possible value.
"""
mutable struct MaximumInvariant <: Invariant
    current_value_counter::Vector{Int}
    current_max::Int
end
MaximumInvariant(max_value::Int) = MaximumInvariant(zeros(Int, max_value), 0)

function init!(invariant::MaximumInvariant, messages::DAGMessagesVector{SingleVariableMessage{IntDecisionValue}})
    for m in messages
        invariant.current_value_counter[m.value.value] += 1
    end
    output_message = eval(invariant, messages)
    invariant.current_max = Int(output_message.value)
    return output_message
end

eval(::MaximumInvariant, messages::DAGMessagesVector{SingleVariableMessage{IntDecisionValue}}) =
    FloatFullMessage(maximum([m.value.value for m in messages]))

"""
    eval(invariant::MaximumInvariant, deltas::DAGMessagesVector{SingleVariableMoveDelta{IntDecisionValue}})

Evaluates the change in maximum value based on proposed changes to input variables.

# Algorithm
1. Check if any new value exceeds current maximum:
   - If yes, return difference between new maximum and current maximum
2. Otherwise:
   - Track changes in value counts using delta_counter
   - Find new maximum by decrementing from current maximum until finding a non-zero count
   - Return difference between new maximum and current maximum
"""
function eval(invariant::MaximumInvariant, deltas::DAGMessagesVector{SingleVariableMoveDelta{IntDecisionValue}})
    new_delta_max = maximum([δ.new_value.value for δ in deltas])
    if new_delta_max >= invariant.current_max
        return FloatDelta(new_delta_max - invariant.current_max)
    end
    delta_counter = zeros(Int, length(invariant.current_value_counter))
    for δ in deltas
        delta_counter[δ.current_value.value] -= 1
        delta_counter[δ.new_value.value] += 1
    end
    new_max = invariant.current_max
    while iszero(delta_counter[new_max] + invariant.current_value_counter[new_max])
        new_max -= 1
    end
    return FloatDelta(new_max - invariant.current_max)
end

function commit!(invariant::MaximumInvariant, deltas::DAGMessagesVector{SingleVariableMoveDelta{IntDecisionValue}})
    invariant.current_max += Int(eval(invariant, deltas).value)
    for δ in deltas
        invariant.current_value_counter[δ.current_value.value] -= 1
        invariant.current_value_counter[δ.new_value.value] += 1
    end
end

@testitem "init!(::MaximumInvariant)" begin
    max_value = 10
    invariant = JuLS.MaximumInvariant(max_value)

    values = [3, 8, 6, 1, 8]
    n = length(values)
    messages = JuLS.DAGMessagesVector([JuLS.SingleVariableMessage(i, values[i]) for i = 1:n])

    output_message = JuLS.init!(invariant, messages)
    @test invariant.current_max == 8
    @test invariant.current_value_counter == [1, 0, 1, 0, 0, 1, 0, 2, 0, 0]
    @test output_message.value == 8
end

@testitem "eval(::MaximumInvariant, ::FullMessage)" begin
    max_value = 10
    invariant = JuLS.MaximumInvariant(max_value)

    values = [3, 8, 6, 1, 8]
    n = length(values)
    messages = JuLS.DAGMessagesVector([JuLS.SingleVariableMessage(i, values[i]) for i = 1:n])

    output_message = JuLS.eval(invariant, messages)
    @test output_message.value == 8
end

@testitem "eval(::MaximumInvariant, ::Delta)" begin
    max_value = 10
    invariant = JuLS.MaximumInvariant(max_value)

    values = [3, 8, 6, 1, 8]
    n = length(values)
    messages = JuLS.DAGMessagesVector([JuLS.SingleVariableMessage(i, values[i]) for i = 1:n])
    JuLS.init!(invariant, messages)

    #Increase maximum
    deltas1 = JuLS.DAGMessagesVector([JuLS.SingleVariableMoveDelta(1, values[1], 10)])
    output_delta = JuLS.eval(invariant, deltas1)
    @test output_delta.value == 2

    #Decrease maximum 1
    deltas2 = JuLS.DAGMessagesVector([
        JuLS.SingleVariableMoveDelta(1, values[1], 4),
        JuLS.SingleVariableMoveDelta(2, values[2], 4),
    ])
    output_delta = JuLS.eval(invariant, deltas2)
    @test output_delta.value == 0

    #Decrease maximum 2
    deltas3 = JuLS.DAGMessagesVector([
        JuLS.SingleVariableMoveDelta(2, values[2], 4),
        JuLS.SingleVariableMoveDelta(5, values[5], 4),
        JuLS.SingleVariableMoveDelta(3, values[3], 4),
    ])

    output_delta = JuLS.eval(invariant, deltas3)
    @test output_delta.value == -4 # new max is 4
end

@testitem "commit!(::MaximumInvariant, ::Delta)" begin
    max_value = 10
    invariant = JuLS.MaximumInvariant(max_value)

    values = [3, 8, 6, 1, 8]
    n = length(values)
    messages = JuLS.DAGMessagesVector([JuLS.SingleVariableMessage(i, values[i]) for i = 1:n])
    JuLS.init!(invariant, messages)

    #Increase maximum
    deltas1 = JuLS.DAGMessagesVector([JuLS.SingleVariableMoveDelta(1, values[1], 10)])
    JuLS.commit!(invariant, deltas1)
    @test invariant.current_max == 10
    @test invariant.current_value_counter == [1, 0, 0, 0, 0, 1, 0, 2, 0, 1]

    #Decrease maximum 1
    deltas2 = JuLS.DAGMessagesVector([JuLS.SingleVariableMoveDelta(1, 10, 4), JuLS.SingleVariableMoveDelta(2, 8, 4)])
    output_delta = JuLS.commit!(invariant, deltas2)
    @test invariant.current_max == 8
    @test invariant.current_value_counter == [1, 0, 0, 2, 0, 1, 0, 1, 0, 0]

    #Decrease maximum 2
    deltas2 = JuLS.DAGMessagesVector([JuLS.SingleVariableMoveDelta(3, 6, 4), JuLS.SingleVariableMoveDelta(5, 8, 4)])
    output_delta = JuLS.commit!(invariant, deltas2)
    @test invariant.current_max == 4
    @test invariant.current_value_counter == [1, 0, 0, 4, 0, 0, 0, 0, 0, 0]
end