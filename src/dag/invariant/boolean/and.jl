# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    AndInvariant <: Invariant

Represents an invariant for the logical AND constraint.
y = x_1 ∩ x_2 ∩ ... ∩ x_n

# Fields
- `nb_false::Int`: Number of variables currently false.
"""
mutable struct AndInvariant <: Invariant
    nb_false::Int
end
AndInvariant() = AndInvariant(0)

eval(::AndInvariant, messages::DAGMessagesVector{SingleVariableMessage{BinaryDecisionValue}}) =
    SingleVariableMessage(all(m.value.value for m in messages))

function eval(invariant::AndInvariant, deltas::DAGMessagesVector{SingleVariableMoveDelta{BinaryDecisionValue}})
    current_value = invariant.nb_false == 0
    new_value = (invariant.nb_false + sum(δ.current_value.value - δ.new_value.value for δ in deltas)) == 0
    if current_value == new_value
        return NoMessage()
    end
    return SingleVariableMoveDelta(current_value, new_value)
end

commit!(invariant::AndInvariant, deltas::DAGMessagesVector{SingleVariableMoveDelta{BinaryDecisionValue}}) =
    invariant.nb_false += sum(δ.current_value.value - δ.new_value.value for δ in deltas)

function init!(invariant::AndInvariant, messages::DAGMessagesVector{SingleVariableMessage{BinaryDecisionValue}})
    invariant.nb_false = sum(1 - m.value.value for m in messages)
    return SingleVariableMessage(invariant.nb_false == 0)
end

@testitem "eval(::AndInvariant, ::SingleVariableMessage)" begin
    m1 = JuLS.SingleVariableMessage(true)
    m2 = JuLS.SingleVariableMessage(false)

    invariant = JuLS.AndInvariant()

    @test JuLS.eval(invariant, JuLS.DAGMessagesVector([m1])) == JuLS.SingleVariableMessage(true)
    @test JuLS.eval(invariant, JuLS.DAGMessagesVector([m2])) == JuLS.SingleVariableMessage(false)

    @test JuLS.eval(invariant, JuLS.DAGMessagesVector([m1, m2])) == JuLS.SingleVariableMessage(false)
    @test JuLS.eval(invariant, JuLS.DAGMessagesVector([m1, m1])) == JuLS.SingleVariableMessage(true)
end

@testitem "eval(::AndInvariant, ::SingleVariableMoveDelta)" begin
    δ1 = JuLS.SingleVariableMoveDelta(true, false)
    δ2 = JuLS.SingleVariableMoveDelta(false, true)

    invariant = JuLS.AndInvariant(1)
    @test JuLS.eval(invariant, JuLS.DAGMessagesVector([δ1])) == JuLS.NoMessage()
    @test JuLS.eval(invariant, JuLS.DAGMessagesVector([δ2])) == JuLS.SingleVariableMoveDelta(false, true)
    @test JuLS.eval(invariant, JuLS.DAGMessagesVector([δ2, δ1])) == JuLS.NoMessage()

    invariant = JuLS.AndInvariant(0)
    @test JuLS.eval(invariant, JuLS.DAGMessagesVector([δ1])) == JuLS.SingleVariableMoveDelta(true, false)
    @test JuLS.eval(invariant, JuLS.DAGMessagesVector([δ2, δ1])) == JuLS.NoMessage()
end

@testitem "commit!(::AndInvariant)" begin
    δ1 = JuLS.SingleVariableMoveDelta(true, false)
    δ2 = JuLS.SingleVariableMoveDelta(false, true)

    invariant = JuLS.AndInvariant(1)

    JuLS.commit!(invariant, JuLS.DAGMessagesVector([δ2]))
    @test invariant.nb_false == 0

    JuLS.commit!(invariant, JuLS.DAGMessagesVector([δ1]))
    @test invariant.nb_false == 1

    JuLS.commit!(invariant, JuLS.DAGMessagesVector([δ1, δ2]))
    @test invariant.nb_false == 1
end

@testitem "init!(::AndInvariant)" begin
    invariant = JuLS.AndInvariant()

    m1 = JuLS.SingleVariableMessage(1, true)
    m2 = JuLS.SingleVariableMessage(2, true)
    m3 = JuLS.SingleVariableMessage(3, false)

    invariant_false = JuLS.AndInvariant()
    messages_false = JuLS.DAGMessagesVector([m1, m2, m3])
    @test JuLS.init!(invariant_false, messages_false) == JuLS.SingleVariableMessage(false)
    @test invariant_false.nb_false == 1

    invariant_true = JuLS.AndInvariant()
    messages_true = JuLS.DAGMessagesVector([m1, m2])
    @test JuLS.init!(invariant_true, messages_true) == JuLS.SingleVariableMessage(true)
    @test invariant_true.nb_false == 0
end