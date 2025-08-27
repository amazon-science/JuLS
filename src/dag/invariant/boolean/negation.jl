# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct NegationInvariant <: Invariant

Turn variables of binary type into their negation.
y = !x
"""
struct NegationInvariant <: StatelessInvariant end

eval(
    invariant::NegationInvariant,
    deltas::DAGMessagesVector{
        <:Union{SingleVariableMoveDelta{BinaryDecisionValue},SingleVariableMessage{BinaryDecisionValue}},
    },
) = DAGMessagesVector([eval(invariant, δ) for δ in deltas])

eval(::NegationInvariant, δ::SingleVariableMoveDelta{BinaryDecisionValue}) =
    SingleVariableMoveDelta{BinaryDecisionValue}(
        δ.index,
        BinaryDecisionValue(!δ.current_value.value),
        BinaryDecisionValue(!δ.new_value.value),
    )

eval(::NegationInvariant, m::SingleVariableMessage{BinaryDecisionValue}) =
    SingleVariableMessage{BinaryDecisionValue}(m.index, BinaryDecisionValue(!m.value.value))

@testitem "eval NegationInvariant" begin
    invariant = JuLS.NegationInvariant()

    delta1 = JuLS.SingleVariableMoveDelta(1, JuLS.BinaryDecisionValue(false), JuLS.BinaryDecisionValue(true))
    delta2 = JuLS.SingleVariableMoveDelta(3, JuLS.BinaryDecisionValue(true), JuLS.BinaryDecisionValue(false))

    @test JuLS.eval(
        invariant,
        JuLS.DAGMessagesVector{JuLS.SingleVariableMoveDelta{JuLS.BinaryDecisionValue}}([delta1, delta2]),
    ).messages == [
        JuLS.SingleVariableMoveDelta(1, JuLS.BinaryDecisionValue(true), JuLS.BinaryDecisionValue(false)),
        JuLS.SingleVariableMoveDelta(3, JuLS.BinaryDecisionValue(false), JuLS.BinaryDecisionValue(true)),
    ]

    message1 = JuLS.SingleVariableMessage(1, JuLS.BinaryDecisionValue(false))
    message2 = JuLS.SingleVariableMessage(27, JuLS.BinaryDecisionValue(true))

    @test JuLS.eval(
        invariant,
        JuLS.DAGMessagesVector{JuLS.SingleVariableMessage{JuLS.BinaryDecisionValue}}([message1, message2]),
    ).messages == [
        JuLS.SingleVariableMessage(1, JuLS.BinaryDecisionValue(true)),
        JuLS.SingleVariableMessage(27, JuLS.BinaryDecisionValue(false)),
    ]
end