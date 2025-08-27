# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    SumInvariant <: StatelessInvariant

Invariant that enforces y = ∑ x_i
"""
struct SumInvariant <: StatelessInvariant end

eval(::SumInvariant, messages::DAGMessagesVector) = sum(messages)

@testitem "eval(::SumInvariant, ::FloatDelta)" begin
    invariant = JuLS.SumInvariant()

    delta1 = JuLS.FloatDelta(12.0)
    delta2 = JuLS.FloatDelta(-2.0)

    @test JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatDelta}([delta1, delta2])) == JuLS.FloatDelta(10.0)

    delta1 = JuLS.FloatDelta(12.0)
    delta2 = JuLS.FloatDelta(-12.0)

    @test iszero(JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatDelta}([delta1, delta2])))
end

@testitem "eval(::SumInvariant, ::FloatFullMessage)" begin
    invariant = JuLS.SumInvariant()

    delta1 = JuLS.FloatFullMessage(12.0)
    delta2 = JuLS.FloatFullMessage(-2.0)

    @test JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatFullMessage}([delta1, delta2])) ==
          JuLS.FloatFullMessage(10.0)
end

@testitem "commit!(::SumInvariant)" begin
    invariant = JuLS.SumInvariant()

    delta1 = JuLS.FloatDelta(12.0)
    delta2 = JuLS.FloatDelta(-2.0)

    @test isnothing(JuLS.commit!(invariant, JuLS.DAGMessagesVector{JuLS.FloatDelta}([delta1, delta2])))
    @test JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatDelta}([delta1, delta2])) == JuLS.FloatDelta(10.0)
end

@testitem "eval(::SumInvariant, ::SingleVariableMessage)" begin
    invariant = JuLS.SumInvariant()

    m1 = JuLS.SingleVariableMessage(false)
    m2 = JuLS.SingleVariableMessage(true)
    m3 = JuLS.SingleVariableMessage(true)
    messages = JuLS.DAGMessagesVector([m1, m2, m3])
    @test JuLS.eval(invariant, messages) == JuLS.SingleVariableMessage(2)

    m1 = JuLS.SingleVariableMessage(3)
    m2 = JuLS.SingleVariableMessage(-2)
    m3 = JuLS.SingleVariableMessage(4)
    messages = JuLS.DAGMessagesVector([m1, m2, m3])
    @test JuLS.eval(invariant, messages) == JuLS.SingleVariableMessage(5)
end

@testitem "eval(::SumInvariant, ::SingleVariableMoveDelta)" begin
    invariant = JuLS.SumInvariant()

    m1 = JuLS.SingleVariableMoveDelta(false, true)
    m2 = JuLS.SingleVariableMoveDelta(true, false)
    m3 = JuLS.SingleVariableMoveDelta(true, false)
    messages = JuLS.DAGMessagesVector([m1, m2, m3])
    @test JuLS.eval(invariant, messages) == JuLS.SingleVariableMoveDelta(2, 1)

    m1 = JuLS.SingleVariableMoveDelta(3, 4)
    m2 = JuLS.SingleVariableMoveDelta(-2, 5)
    m3 = JuLS.SingleVariableMoveDelta(4, -6)
    messages = JuLS.DAGMessagesVector([m1, m2, m3])
    @test JuLS.eval(invariant, messages) == JuLS.SingleVariableMoveDelta(5, 3)
end