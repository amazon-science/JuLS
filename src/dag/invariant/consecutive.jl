# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    ConsecutiveInvariant <: Invariant

Check if x and y have consecutive values (ex: 3 and 4 or 8 and 7). 
The values are bound and make a cycle, meaning that if the values are at the extreme, they are considered as consecutive.
(i.e. x = 1 and y = n are consecutive).
"""
mutable struct ConsecutiveInvariant <: Invariant
    current_values::PairMapping{Int}
    current_output::Bool
    min_value::Int
    max_value::Int
end
ConsecutiveInvariant(min_value::Int, max_value::Int) =
    ConsecutiveInvariant(PairMapping{Int}(), false, min_value, max_value)

function init!(invariant::ConsecutiveInvariant, messages::DAGMessagesVector{SingleVariableMessage{IntDecisionValue}})
    @assert length(messages) == 2 "This invariant must have 2 parents"
    setkeys!(invariant.current_values, [m.index for m in messages]...)
    for m in messages
        invariant.current_values[m.index] = m.value.value
    end
    invariant.current_output = Bool(
        is_consecutive(
            invariant.min_value,
            invariant.max_value,
            first_value(invariant.current_values),
            second_value(invariant.current_values),
        ),
    )
    return FloatFullMessage(invariant.current_output)
end

eval(invariant::ConsecutiveInvariant, messages::DAGMessagesVector{SingleVariableMessage{IntDecisionValue}}) =
    FloatFullMessage(
        is_consecutive(invariant.min_value, invariant.max_value, messages[1].value.value, messages[2].value.value),
    )


function eval(invariant::ConsecutiveInvariant, deltas::DAGMessagesVector{SingleVariableMoveDelta{IntDecisionValue}})
    new_values = deepcopy(invariant.current_values)
    for δ in deltas
        new_values[δ.index] = δ.new_value.value
    end
    return FloatDelta(
        is_consecutive(invariant.min_value, invariant.max_value, first_value(new_values), second_value(new_values)) -
        invariant.current_output,
    )
end

function commit!(invariant::ConsecutiveInvariant, deltas::DAGMessagesVector{SingleVariableMoveDelta{IntDecisionValue}})
    for δ in deltas
        invariant.current_values[δ.index] = δ.new_value.value
    end
    invariant.current_output = Bool(
        is_consecutive(
            invariant.min_value,
            invariant.max_value,
            first_value(invariant.current_values),
            second_value(invariant.current_values),
        ),
    )
end

is_consecutive(min_value::Int, max_value::Int, value1::Int, value2::Int) =
    abs(value1 - value2) == 1 || abs(value1 - value2) == max_value - min_value


@testitem "is_consecutive()" begin
    n = 10

    @test JuLS.is_consecutive(1, n, 1, 2)
    @test JuLS.is_consecutive(1, n, 2, 1)
    @test !JuLS.is_consecutive(1, n, 4, 4)
    @test !JuLS.is_consecutive(1, n, 1, 3)
    @test JuLS.is_consecutive(1, n, 1, 10)
    @test JuLS.is_consecutive(1, n, 10, 1)
end


@testitem "init!(::ConsecutiveInvariant)" begin
    n = 10
    invariant = JuLS.ConsecutiveInvariant(1, n)

    messages = JuLS.DAGMessagesVector([JuLS.SingleVariableMessage(3, 1), JuLS.SingleVariableMessage(5, 8)])
    output_message = JuLS.init!(invariant, messages)

    @test output_message.value == 0
    @test invariant.current_values[3] == 1
    @test invariant.current_values[5] == 8
    @test invariant.current_output == false
end

@testitem "eval(::ConsecutiveInvariant, ::FullMessage)" begin
    n = 10
    invariant = JuLS.ConsecutiveInvariant(1, n)

    messages = JuLS.DAGMessagesVector([JuLS.SingleVariableMessage(3, 1), JuLS.SingleVariableMessage(5, 8)])
    @test JuLS.eval(invariant, messages).value == 0

    messages = JuLS.DAGMessagesVector([JuLS.SingleVariableMessage(3, 2), JuLS.SingleVariableMessage(5, 1)])
    @test JuLS.eval(invariant, messages).value == 1

    messages = JuLS.DAGMessagesVector([JuLS.SingleVariableMessage(3, 10), JuLS.SingleVariableMessage(5, 1)])
    @test JuLS.eval(invariant, messages).value == 1
end

@testitem "eval(::ConsecutiveInvariant, ::Delta)" begin
    n = 10
    invariant = JuLS.ConsecutiveInvariant(1, n)

    messages = JuLS.DAGMessagesVector([JuLS.SingleVariableMessage(3, 1), JuLS.SingleVariableMessage(5, 8)])
    JuLS.init!(invariant, messages)

    input_delta = JuLS.DAGMessagesVector([JuLS.SingleVariableMoveDelta(3, 1, 9)])
    output_delta = JuLS.eval(invariant, input_delta)
    @test output_delta.value == 1

    input_delta = JuLS.DAGMessagesVector([JuLS.SingleVariableMoveDelta(3, 1, 4)])
    output_delta = JuLS.eval(invariant, input_delta)
    @test output_delta.value == 0

    input_delta =
        JuLS.DAGMessagesVector([JuLS.SingleVariableMoveDelta(3, 1, 10), JuLS.SingleVariableMoveDelta(5, 8, 1)])
    output_delta = JuLS.eval(invariant, input_delta)
    @test output_delta.value == 1
end

@testitem "commit!(::ConsecutiveInvariant)" begin
    n = 10
    invariant = JuLS.ConsecutiveInvariant(1, n)

    messages = JuLS.DAGMessagesVector([JuLS.SingleVariableMessage(3, 1), JuLS.SingleVariableMessage(5, 8)])
    JuLS.init!(invariant, messages)

    input_delta = JuLS.DAGMessagesVector([JuLS.SingleVariableMoveDelta(3, 1, 9)])
    JuLS.commit!(invariant, input_delta)
    @test invariant.current_values[3] == 9
    @test invariant.current_values[5] == 8
    @test invariant.current_output == true

    input_delta = JuLS.DAGMessagesVector([JuLS.SingleVariableMoveDelta(3, 1, 4)])
    output_delta = JuLS.eval(invariant, input_delta)
    @test output_delta.value == -1
end