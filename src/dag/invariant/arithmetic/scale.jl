# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct ScaleInvariant <: StatelessInvariant

Very simple invariant that just multiplies the received scalar message with a constant.
Basically y = α * x
"""
struct ScaleInvariant <: StatelessInvariant
    α::Float64
end

InputType(::ScaleInvariant) = MultiType()

eval(invariant::ScaleInvariant, messages::MultiTypedDAGMessages) =
    sum(eval(invariant, m) for m in all_messages(messages))

eval(invariant::ScaleInvariant, δ::ScalarDelta) = invariant.α * δ

eval(invariant::ScaleInvariant, message::ScalarFullMessage) = invariant.α * message

eval(invariant::ScaleInvariant, δ::SingleVariableMoveDelta) =
    FloatDelta(invariant.α * (δ.new_value.value - δ.current_value.value))

eval(invariant::ScaleInvariant, message::SingleVariableMessage) = FloatFullMessage(invariant.α * message.value.value)

@testitem "Test eval" begin
    invariant = JuLS.ScaleInvariant(10.0)

    delta1 = JuLS.FloatDelta(12.0)
    delta2 = JuLS.FloatDelta(-2.0)

    @test JuLS.eval(invariant, JuLS.MultiTypedDAGMessages{JuLS.Delta}([delta1, delta2])) == JuLS.FloatDelta(100.0)
end

@testitem "Test eval 2" begin
    invariant = JuLS.ScaleInvariant(11.0)

    delta1 = JuLS.FloatDelta(12.0)
    delta2 = JuLS.FloatDelta(-12.0)

    @test iszero(JuLS.eval(invariant, JuLS.MultiTypedDAGMessages{JuLS.Delta}([delta1, delta2])))
end

@testitem "eval(::FullMessage)" begin
    invariant = JuLS.ScaleInvariant(11.0)

    delta1 = JuLS.FloatFullMessage(12.0)
    delta2 = JuLS.FloatFullMessage(-12.0)

    @test JuLS.eval(invariant, JuLS.MultiTypedDAGMessages{JuLS.FullMessage}([delta1, delta2])) ==
          JuLS.FloatFullMessage(0.0)

    delta1 = JuLS.FloatFullMessage(12.0)
    delta2 = JuLS.FloatFullMessage(-2.0)

    @test JuLS.eval(invariant, JuLS.MultiTypedDAGMessages{JuLS.FullMessage}([delta1, delta2])) ==
          JuLS.FloatFullMessage(110.0)
end

@testitem "eval(::MultiTypedDAGMessages)" begin
    invariant = JuLS.ScaleInvariant(9.0)

    delta1 = JuLS.FloatFullMessage(12.0)
    delta2 = JuLS.FloatFullMessage(-12.0)

    input = JuLS.DAGMessage[]
    push!(input, delta1)
    push!(input, delta2)

    @test JuLS.eval(invariant, JuLS.MultiTypedDAGMessages(input)) == JuLS.FloatFullMessage(0.0)

    delta1 = JuLS.FloatFullMessage(12.0)
    delta2 = JuLS.ObjectiveFullMessage(-2.0)

    input = JuLS.DAGMessage[]
    push!(input, delta1)
    push!(input, delta2)

    @test JuLS.eval(invariant, JuLS.MultiTypedDAGMessages(input)) == JuLS.FloatFullMessage(90.0)
end

@testitem "Test commit" begin
    invariant = JuLS.ScaleInvariant(2.0)

    delta1 = JuLS.FloatDelta(12.0)
    delta2 = JuLS.FloatDelta(-2.0)

    JuLS.commit!(invariant, JuLS.MultiTypedDAGMessages{JuLS.Delta}([delta1, delta2]))

    @test JuLS.eval(invariant, JuLS.MultiTypedDAGMessages{JuLS.Delta}([delta1, delta2])) == JuLS.FloatDelta(20.0)
end

@testitem "eval(::ScaleInvariant, ::DAGMessagesVector{<:DecisionDelta{T}})" begin
    invariant = JuLS.ScaleInvariant(2.0)

    delta1 = JuLS.SingleVariableMoveDelta(12, 4)
    delta2 = JuLS.SingleVariableMoveDelta(false, true)
    delta3 = JuLS.SingleVariableMoveDelta(true, false)

    @test JuLS.eval(invariant, delta1) == JuLS.FloatDelta(-16.0)
    @test JuLS.eval(invariant, delta2) == JuLS.FloatDelta(2.0)
    @test JuLS.eval(invariant, JuLS.MultiTypedDAGMessages{JuLS.Delta}([delta2, delta3])) == JuLS.FloatDelta(0.0)
end

@testitem "eval(::ScaleInvariant, ::DAGMessagesVector{<:DecisionMessage{T}})" begin
    invariant = JuLS.ScaleInvariant(2.0)

    delta1 = JuLS.SingleVariableMessage(12)
    delta2 = JuLS.SingleVariableMessage(false)
    delta3 = JuLS.SingleVariableMessage(true)

    @test JuLS.eval(invariant, delta1) == JuLS.FloatFullMessage(24.0)
    @test JuLS.eval(invariant, delta3) == JuLS.FloatFullMessage(2.0)
    @test JuLS.eval(invariant, JuLS.MultiTypedDAGMessages{JuLS.Delta}([delta2, delta3])) == JuLS.FloatFullMessage(2.0)
end