# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    AmongInvariant <: StatelessInvariant

This invariant represents the constraint Among(X, S, n) which enforces 
y = |{x ∈ X : x.value ∈ S}|
"""
struct AmongInvariant <: StatelessInvariant
    set::AbstractSet
end

function eval(invariant::AmongInvariant, messages::DAGMessagesVector{SingleVariableMessage{T}}) where {T<:DecisionValue}
    return FloatFullMessage(sum(isconsuming(invariant, message.value) for message in messages))
end

function eval(invariant::AmongInvariant, deltas::DAGMessagesVector{SingleVariableMoveDelta{T}}) where {T<:DecisionValue}
    return FloatDelta(
        sum(isconsuming(invariant, δ.new_value) - isconsuming(invariant, δ.current_value) for δ in deltas),
    )
end

"""
    struct WeightedAmongInvariant <: StatelessInvariant

This invariant represents the constraint WeightedAmong(X, S, W, n) which enforces 
y = sum(W[i] * (x[i].value ∈ S))
"""
struct WeightedAmongInvariant <: StatelessInvariant
    set::AbstractSet
    weights::Vector{<:Number}
end

function eval(
    invariant::WeightedAmongInvariant,
    messages::DAGMessagesVector{SingleVariableMessage{T}},
) where {T<:DecisionValue}
    return FloatFullMessage(
        sum(isconsuming(invariant, message.value) * invariant.weights[message.index] for message in messages),
    )
end

function eval(
    invariant::WeightedAmongInvariant,
    deltas::DAGMessagesVector{SingleVariableMoveDelta{T}},
) where {T<:DecisionValue}
    return FloatDelta(
        sum(
            (isconsuming(invariant, δ.new_value) - isconsuming(invariant, δ.current_value)) *
            invariant.weights[δ.index] for δ in deltas
        ),
    )
end

"""
    isconsuming(invariant::AmongInvariant, decision_value::T) where {T<:DecisionValue}

Check if decision_value ∈ invariant.set
"""
isconsuming(invariant::Union{AmongInvariant,WeightedAmongInvariant}, decision_value::T) where {T<:DecisionValue} =
    decision_value.value in invariant.set

@testitem "isconsuming()" begin
    invariant = JuLS.AmongInvariant(JuLS.Singleton(1))

    @test JuLS.isconsuming(invariant, JuLS.IntDecisionValue(1))
    @test !JuLS.isconsuming(invariant, JuLS.IntDecisionValue(2))
end

@testitem "eval(::AmongInvariant, ::Delta)" begin

    δ1 = JuLS.SingleVariableMoveDelta(1, JuLS.IntDecisionValue(1), JuLS.IntDecisionValue(2))
    δ2 = JuLS.SingleVariableMoveDelta(2, JuLS.IntDecisionValue(2), JuLS.IntDecisionValue(1))
    δ3 = JuLS.SingleVariableMoveDelta(3, JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(2))

    invariant = JuLS.AmongInvariant(JuLS.Singleton(2))

    deltas = JuLS.DAGMessagesVector([δ1])
    @test JuLS.eval(invariant, deltas) == JuLS.FloatDelta(1.0)

    deltas = JuLS.DAGMessagesVector([δ2])
    @test JuLS.eval(invariant, deltas) == JuLS.FloatDelta(-1.0)

    deltas = JuLS.DAGMessagesVector([δ3])
    @test JuLS.eval(invariant, deltas) == JuLS.FloatDelta(1.0)

    deltas = JuLS.DAGMessagesVector([δ1, δ2])
    @test JuLS.eval(invariant, deltas) == JuLS.FloatDelta(0.0)

    deltas = JuLS.DAGMessagesVector([δ1, δ3])
    @test JuLS.eval(invariant, deltas) == JuLS.FloatDelta(2.0)

    deltas = JuLS.DAGMessagesVector([δ1, δ2, δ3])
    @test JuLS.eval(invariant, deltas) == JuLS.FloatDelta(1.0)
end

@testitem "eval(::AmongInvariant, ::Message)" begin
    m1 = JuLS.SingleVariableMessage(1, JuLS.IntDecisionValue(2))
    m2 = JuLS.SingleVariableMessage(2, JuLS.IntDecisionValue(1))
    m3 = JuLS.SingleVariableMessage(3, JuLS.IntDecisionValue(2))

    invariant = JuLS.AmongInvariant(JuLS.Singleton(2))

    messages = JuLS.DAGMessagesVector([m1])
    @test JuLS.eval(invariant, messages) == JuLS.FloatFullMessage(1.0)

    messages = JuLS.DAGMessagesVector([m2])
    @test JuLS.eval(invariant, messages) == JuLS.FloatFullMessage(0.0)

    messages = JuLS.DAGMessagesVector([m1, m2, m3])
    @test JuLS.eval(invariant, messages) == JuLS.FloatFullMessage(2.0)
end

@testitem "eval(::WeightedAmongInvariant, ::Delta)" begin

    δ1 = JuLS.SingleVariableMoveDelta(1, JuLS.IntDecisionValue(1), JuLS.IntDecisionValue(2))
    δ2 = JuLS.SingleVariableMoveDelta(2, JuLS.IntDecisionValue(2), JuLS.IntDecisionValue(1))
    δ3 = JuLS.SingleVariableMoveDelta(3, JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(2))

    weights = [12, 5, 8]

    invariant = JuLS.WeightedAmongInvariant(JuLS.Singleton(2), weights)

    deltas = JuLS.DAGMessagesVector([δ1])
    @test JuLS.eval(invariant, deltas) == JuLS.FloatDelta(12.0)

    deltas = JuLS.DAGMessagesVector([δ2])
    @test JuLS.eval(invariant, deltas) == JuLS.FloatDelta(-5.0)

    deltas = JuLS.DAGMessagesVector([δ3])
    @test JuLS.eval(invariant, deltas) == JuLS.FloatDelta(8.0)

    deltas = JuLS.DAGMessagesVector([δ1, δ2])
    @test JuLS.eval(invariant, deltas) == JuLS.FloatDelta(7.0)

    deltas = JuLS.DAGMessagesVector([δ1, δ3])
    @test JuLS.eval(invariant, deltas) == JuLS.FloatDelta(20.0)

    deltas = JuLS.DAGMessagesVector([δ1, δ2, δ3])
    @test JuLS.eval(invariant, deltas) == JuLS.FloatDelta(15.0)
end

@testitem "eval(::WeightedAmongInvariant, ::Message)" begin
    m1 = JuLS.SingleVariableMessage(1, JuLS.IntDecisionValue(2))
    m2 = JuLS.SingleVariableMessage(2, JuLS.IntDecisionValue(1))
    m3 = JuLS.SingleVariableMessage(3, JuLS.IntDecisionValue(2))

    weights = [12, 5, 8]

    invariant = JuLS.WeightedAmongInvariant(JuLS.Singleton(2), weights)

    messages = JuLS.DAGMessagesVector([m1])
    @test JuLS.eval(invariant, messages) == JuLS.FloatFullMessage(12.0)

    messages = JuLS.DAGMessagesVector([m2])
    @test JuLS.eval(invariant, messages) == JuLS.FloatFullMessage(0.0)

    messages = JuLS.DAGMessagesVector([m1, m2, m3])
    @test JuLS.eval(invariant, messages) == JuLS.FloatFullMessage(20.0)
end