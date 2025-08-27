# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    IsDifferentInvariant{T} <: StatelessInvariant

Invariant checking if variable is different than a given value `v`
b = (x != v)
"""
struct IsDifferentInvariant{T} <: StatelessInvariant where {T<:DecisionValue}
    value::T
end

eval(
    invariant::IsDifferentInvariant{T},
    deltas::DAGMessagesVector{<:Union{SingleVariableMoveDelta{<:T},SingleVariableMessage{<:T}}},
) where {T<:DecisionValue} = DAGMessagesVector([eval(invariant, δ_i) for δ_i in deltas])

eval(invariant::IsDifferentInvariant{T}, message::SingleVariableMessage{T}) where {T<:DecisionValue} =
    SingleVariableMessage(message.index, message.value != invariant.value)

function eval(invariant::IsDifferentInvariant{T}, δ::SingleVariableMoveDelta{T}) where {T<:DecisionValue}
    current_value = δ.current_value != invariant.value
    new_value = δ.new_value != invariant.value
    if current_value == new_value
        return NoMessage()
    end
    return SingleVariableMoveDelta(δ.index, current_value, new_value)
end

@testitem "eval(::IsDifferentInvariant, ::SingleVariableMessage)" begin
    invariant = JuLS.IsDifferentInvariant(JuLS.DecisionValue(3))

    @test JuLS.eval(invariant, JuLS.SingleVariableMessage(1, JuLS.IntDecisionValue(1))) ==
          JuLS.SingleVariableMessage(1, true)

    @test JuLS.eval(invariant, JuLS.SingleVariableMessage(2, JuLS.IntDecisionValue(3))) ==
          JuLS.SingleVariableMessage(2, false)
end

@testitem "eval(::IsDifferentInvariant, ::SingleVariableMoveDelta)" begin
    invariant = JuLS.IsDifferentInvariant(JuLS.DecisionValue(3))

    @test JuLS.eval(invariant, JuLS.SingleVariableMoveDelta(1, JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(2))) ==
          JuLS.SingleVariableMoveDelta(1, false, true)

    @test JuLS.eval(invariant, JuLS.SingleVariableMoveDelta(2, JuLS.IntDecisionValue(2), JuLS.IntDecisionValue(3))) ==
          JuLS.SingleVariableMoveDelta(2, true, false)

    @test JuLS.eval(invariant, JuLS.SingleVariableMoveDelta(3, JuLS.IntDecisionValue(1), JuLS.IntDecisionValue(2))) ==
          JuLS.NoMessage()

    @test JuLS.eval(invariant, JuLS.SingleVariableMoveDelta(4, JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(3))) ==
          JuLS.NoMessage()
end