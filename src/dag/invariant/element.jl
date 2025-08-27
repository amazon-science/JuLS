# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct ElementInvariant{T} <: StatelessInvariant where {T<:DecisionValue}

Given a message with an IntDecisionValue i, the ElementInvariant returns elements[i] which is a message with a DecisionValue of type T.
y = elements[x]
"""
struct ElementInvariant{T} <: StatelessInvariant where {T<:DecisionValue}
    output_variable_index::Int
    elements::Vector{T}
end

InputType(::ElementInvariant) = SingleType()

function eval(invariant::ElementInvariant{T}, message::SingleVariableMessage{IntDecisionValue}) where {T<:DecisionValue}
    return SingleVariableMessage{T}(invariant.output_variable_index, invariant.elements[message.value.value])
end

function eval(invariant::ElementInvariant{T}, δ::SingleVariableMoveDelta{IntDecisionValue}) where {T<:DecisionValue}
    current_value = invariant.elements[δ.current_value.value]
    new_value = invariant.elements[δ.new_value.value]
    if current_value == new_value
        return NoMessage()
    end
    return SingleVariableMoveDelta{T}(invariant.output_variable_index, current_value, new_value)
end

@testitem "eval(::ElementInvariant, ::SingleVariableMessage)" begin
    vec = [JuLS.IntDecisionValue(6), JuLS.IntDecisionValue(1), JuLS.IntDecisionValue(3)]

    inv = JuLS.ElementInvariant(2, vec)
    decision_message = JuLS.SingleVariableMessage(1, JuLS.IntDecisionValue(2))

    output_message = JuLS.eval(inv, decision_message)

    @test output_message.index == 2
    @test output_message.value == JuLS.IntDecisionValue(1)
end

@testitem "eval(::ElementInvariant, ::SingleVariableMoveDelta)" begin
    vec = [JuLS.IntDecisionValue(6), JuLS.IntDecisionValue(1), JuLS.IntDecisionValue(17), JuLS.IntDecisionValue(17)]

    inv = JuLS.ElementInvariant(2, vec)

    decision_delta = JuLS.SingleVariableMoveDelta(1, JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(1))

    output_delta = JuLS.eval(inv, decision_delta)

    @test output_delta.index == 2
    @test output_delta.current_value == JuLS.IntDecisionValue(17)
    @test output_delta.new_value == JuLS.IntDecisionValue(6)

    decision_delta = JuLS.SingleVariableMoveDelta(1, JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(4))
    @test JuLS.eval(inv, decision_delta) == JuLS.NoMessage()
end