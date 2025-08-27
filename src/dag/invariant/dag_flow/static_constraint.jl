# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct StaticConstraintInvariant <: StatelessInvariant

Invariant to factor the ConstraintDelta by the alpha that defines how quick we 
want to return to feasibility the higher the α
eval: returns the factored ConstraintDelta by α
"""
struct StaticConstraintInvariant <: StatelessInvariant
    α::Float64
end

eval(invariant::StaticConstraintInvariant, δ::ScalarDelta) = convert(ConstraintDelta, invariant.α * δ)
eval(invariant::StaticConstraintInvariant, message::ScalarFullMessage) =
    convert(ConstraintFullMessage, invariant.α * message)

eval(
    invariant::StaticConstraintInvariant,
    deltas::Union{DAGMessagesVector{<:ScalarDelta},DAGMessagesVector{<:ScalarFullMessage}},
) = eval(invariant, sum(deltas))

@testitem "Test eval" begin
    invariant = JuLS.StaticConstraintInvariant(10.0)

    delta1 = JuLS.FloatDelta(12.0)
    delta2 = JuLS.FloatDelta(-2.0)

    @test JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatDelta}([delta1, delta2])) == JuLS.ConstraintDelta(100.0)
end

@testitem "Test eval 2" begin
    invariant = JuLS.StaticConstraintInvariant(10.0)

    delta1 = JuLS.FloatDelta(12.0)
    delta2 = JuLS.FloatDelta(-12.0)

    @test iszero(JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatDelta}([delta1, delta2])))
end

@testitem "Test eval full message" begin
    invariant = JuLS.StaticConstraintInvariant(10.0)

    delta1 = JuLS.FloatFullMessage(12.0)
    delta2 = JuLS.FloatFullMessage(-2.0)

    @test JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatFullMessage}([delta1, delta2])) ==
          JuLS.ConstraintFullMessage(100.0)
end

@testitem "Test commit" begin
    invariant = JuLS.StaticConstraintInvariant(10.0)

    delta1 = JuLS.FloatDelta(12.0)
    delta2 = JuLS.FloatDelta(-2.0)

    JuLS.commit!(invariant, JuLS.DAGMessagesVector{JuLS.FloatDelta}([delta1, delta2]))

    @test JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatDelta}([delta1, delta2])) == JuLS.ConstraintDelta(100.0)
end