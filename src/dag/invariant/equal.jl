# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    EqualInvariant{T} <: Invariant where {T<:DecisionValue}

Invariant representing the constraint x = y.
"""
struct EqualInvariant{T} <: Invariant where {T<:DecisionValue}
    current_values::PairMapping{T}
end
EqualInvariant{T}() where {T} = EqualInvariant(PairMapping{T}())

function init!(
    invariant::EqualInvariant{T},
    messages::DAGMessagesVector{SingleVariableMessage{T}},
) where {T<:DecisionValue}
    indexes = [m.index for m in messages]
    @assert length(messages) == 2 "This invariant must have 2 parents : here $indexes"
    setkeys!(invariant.current_values, indexes...)
    for m in messages
        invariant.current_values[m.index] = m.value
    end
    return FloatFullMessage(first_value(invariant.current_values) == second_value(invariant.current_values))
end

eval(::EqualInvariant{T}, messages::DAGMessagesVector{SingleVariableMessage{T}}) where {T<:DecisionValue} =
    FloatFullMessage(messages[1].value == messages[2].value)

function eval(
    invariant::EqualInvariant{T},
    deltas::DAGMessagesVector{SingleVariableMoveDelta{T}},
) where {T<:DecisionValue}
    new_values = deepcopy(invariant.current_values)
    for δ in deltas
        new_values[δ.index] = δ.new_value
    end
    return FloatDelta(
        (first_value(new_values) == second_value(new_values)) -
        (first_value(invariant.current_values) == second_value(invariant.current_values)),
    )
end

function commit!(
    invariant::EqualInvariant{T},
    deltas::DAGMessagesVector{SingleVariableMoveDelta{T}},
) where {T<:DecisionValue}
    for δ in deltas
        invariant.current_values[δ.index] = δ.new_value
    end
end

@testitem "init!(::EqualInvariant)" begin
    invariant = JuLS.EqualInvariant{JuLS.IntDecisionValue}()
    x = JuLS.SingleVariableMessage(3, JuLS.IntDecisionValue(12))
    y = JuLS.SingleVariableMessage(37, JuLS.IntDecisionValue(9))

    message = JuLS.init!(invariant, JuLS.DAGMessagesVector([x, y]))

    @test message.value == 0
    @test invariant.current_values[3].value == 12
    @test invariant.current_values[37].value == 9
end

@testitem "eval(::EqualInvariant, ::FullMessage)" begin
    invariant = JuLS.EqualInvariant{JuLS.IntDecisionValue}()
    x = JuLS.SingleVariableMessage(3, JuLS.IntDecisionValue(12))
    y = JuLS.SingleVariableMessage(37, JuLS.IntDecisionValue(9))

    JuLS.init!(invariant, JuLS.DAGMessagesVector([x, y]))

    x1 = JuLS.SingleVariableMessage(3, JuLS.IntDecisionValue(4))
    y1 = JuLS.SingleVariableMessage(37, JuLS.IntDecisionValue(4))
    message = JuLS.eval(invariant, JuLS.DAGMessagesVector([x1, y1]))
    @test message.value == 1

    x2 = JuLS.SingleVariableMessage(3, JuLS.IntDecisionValue(4))
    y2 = JuLS.SingleVariableMessage(37, JuLS.IntDecisionValue(18))
    message = JuLS.eval(invariant, JuLS.DAGMessagesVector([x2, y2]))
    @test message.value == 0
end

@testitem "eval(::EqualInvariant, ::Delta)" begin
    invariant = JuLS.EqualInvariant{JuLS.IntDecisionValue}()
    x = JuLS.SingleVariableMessage(3, JuLS.IntDecisionValue(12))
    y = JuLS.SingleVariableMessage(37, JuLS.IntDecisionValue(9))
    JuLS.init!(invariant, JuLS.DAGMessagesVector([x, y]))

    x1 = JuLS.SingleVariableMoveDelta(3, JuLS.IntDecisionValue(12), JuLS.IntDecisionValue(5))
    y1 = JuLS.SingleVariableMoveDelta(37, JuLS.IntDecisionValue(9), JuLS.IntDecisionValue(5))

    delta = JuLS.eval(invariant, JuLS.DAGMessagesVector([x1, y1]))
    @test delta.value == 1

    x2 = JuLS.SingleVariableMoveDelta(3, JuLS.IntDecisionValue(12), JuLS.IntDecisionValue(8))
    y2 = JuLS.SingleVariableMoveDelta(37, JuLS.IntDecisionValue(9), JuLS.IntDecisionValue(1))

    delta = JuLS.eval(invariant, JuLS.DAGMessagesVector([x2, y2]))
    @test delta.value == 0

    x3 = JuLS.SingleVariableMoveDelta(3, JuLS.IntDecisionValue(12), JuLS.IntDecisionValue(9))

    delta = JuLS.eval(invariant, JuLS.DAGMessagesVector([x3]))
    @test delta.value == 1
end

@testitem "commit!(::EqualInvariant)" begin
    invariant = JuLS.EqualInvariant{JuLS.IntDecisionValue}()
    x = JuLS.SingleVariableMessage(3, JuLS.IntDecisionValue(12))
    y = JuLS.SingleVariableMessage(37, JuLS.IntDecisionValue(9))
    JuLS.init!(invariant, JuLS.DAGMessagesVector([x, y]))

    x1 = JuLS.SingleVariableMoveDelta(3, JuLS.IntDecisionValue(12), JuLS.IntDecisionValue(5))
    y1 = JuLS.SingleVariableMoveDelta(37, JuLS.IntDecisionValue(9), JuLS.IntDecisionValue(5))

    JuLS.commit!(invariant, JuLS.DAGMessagesVector([x1, y1]))

    @test invariant.current_values[3].value == 5
    @test invariant.current_values[37].value == 5

    x2 = JuLS.SingleVariableMoveDelta(3, JuLS.IntDecisionValue(12), JuLS.IntDecisionValue(8))
    y2 = JuLS.SingleVariableMoveDelta(37, JuLS.IntDecisionValue(9), JuLS.IntDecisionValue(1))
    delta = JuLS.eval(invariant, JuLS.DAGMessagesVector([x2, y2]))
    @test delta.value == -1
end



