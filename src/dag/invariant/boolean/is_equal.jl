# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct IsEqualInvariant <: Invariant

Invariant checking if variables are equal to a given value v.
b = (x == v)
"""
struct IsEqualInvariant{T<:DecisionValue} <: StatelessInvariant
    value_to_match::T
end

eval(
    invariant::IsEqualInvariant{T},
    deltas::DAGMessagesVector{<:Union{SingleVariableMoveDelta{<:T},SingleVariableMessage{<:T}}},
) where {T<:DecisionValue} = DAGMessagesVector([eval(invariant, δ_i) for δ_i in deltas])

eval(invariant::IsEqualInvariant{T}, δ::SingleVariableMoveDelta{<:T}) where {T<:DecisionValue} =
    SingleVariableMoveDelta(
        δ.index,
        δ.current_value == invariant.value_to_match,
        δ.new_value == invariant.value_to_match,
    )

eval(invariant::IsEqualInvariant{T}, m::SingleVariableMessage{<:T}) where {T<:DecisionValue} =
    SingleVariableMessage(m.index, m.value == invariant.value_to_match)


@testitem "eval IsEqualInvariant" begin
    using Dates
    invariant = JuLS.IsEqualInvariant(JuLS.IntDecisionValue(3))

    delta1 = JuLS.SingleVariableMoveDelta(1, JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(2))
    delta2 = JuLS.SingleVariableMoveDelta(7, JuLS.IntDecisionValue(2), JuLS.IntDecisionValue(3))
    delta3 = JuLS.SingleVariableMoveDelta(8, JuLS.IntDecisionValue(1), JuLS.IntDecisionValue(2))

    @test JuLS.eval(invariant, JuLS.DAGMessagesVector([delta1, delta2, delta3])).messages == [
        JuLS.SingleVariableMoveDelta(1, JuLS.BinaryDecisionValue(true), JuLS.BinaryDecisionValue(false)),
        JuLS.SingleVariableMoveDelta(7, JuLS.BinaryDecisionValue(false), JuLS.BinaryDecisionValue(true)),
        JuLS.SingleVariableMoveDelta(8, JuLS.BinaryDecisionValue(false), JuLS.BinaryDecisionValue(false)),
    ]

    message1 = JuLS.SingleVariableMessage(1, JuLS.IntDecisionValue(1))
    message2 = JuLS.SingleVariableMessage(27, JuLS.IntDecisionValue(3))

    @test JuLS.eval(invariant, JuLS.DAGMessagesVector([message1, message2])).messages == [
        JuLS.SingleVariableMessage(1, JuLS.BinaryDecisionValue(false)),
        JuLS.SingleVariableMessage(27, JuLS.BinaryDecisionValue(true)),
    ]
end