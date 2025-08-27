# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    ComparatorInvariant <: SummableDeltaInvariant

Invariant that compares a sum of values against a capacity threshold, typically used in constrained optimization problems.
y = max(0, ∑ x - C)

# Fields
- `current_value::Float64`: Current accumulated sum
- `original_capacity::Float64`: Threshold value for comparison
"""
mutable struct ComparatorInvariant <: SummableDeltaInvariant
    current_value::Float64
    original_capacity::Float64
end

ComparatorInvariant(capacity::Number) = ComparatorInvariant(0.0, capacity)

eval(invariant::ComparatorInvariant, message::FloatFullMessage) =
    FloatFullMessage(max(0, message.value - invariant.original_capacity))

eval(invariant::ComparatorInvariant, δ::FloatDelta) = FloatDelta(
    max(0, δ.value + invariant.current_value - invariant.original_capacity) -
    max(0, invariant.current_value - invariant.original_capacity),
)

commit!(invariant::ComparatorInvariant, δ::FloatDelta) = (invariant.current_value += δ.value)

init!(invariant::ComparatorInvariant, message::FloatFullMessage) =
    (invariant.current_value = message.value; eval(invariant, message))

@testitem "init!(::ComparatorInvariant)" begin
    invariant = JuLS.ComparatorInvariant(10.0)

    JuLS.init!(invariant, JuLS.FloatFullMessage(2.0))
    @test invariant.original_capacity == 10.0
    @test invariant.current_value == 2.0

    invariant = JuLS.ComparatorInvariant(5.0, 10.0) # The initial value should be ignored

    JuLS.init!(invariant, JuLS.FloatFullMessage(2.0))
    @test invariant.current_value == 2.0
end

@testitem "Test eval" begin
    invariant = JuLS.ComparatorInvariant(10.0)

    delta1 = JuLS.FloatDelta(2.0)
    delta2 = JuLS.FloatDelta(3.0)
    delta3 = JuLS.FloatDelta(10.0)

    @test iszero(JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatDelta}([delta1, delta2])))
    @test JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatDelta}([delta1, delta2, delta3])) ==
          JuLS.FloatDelta(5.0)
end

@testitem "Test eval 2" begin
    invariant = JuLS.ComparatorInvariant(-10.0)

    delta1 = JuLS.FloatDelta(2.0)
    delta2 = JuLS.FloatDelta(3.0)
    delta3 = JuLS.FloatDelta(10.0)

    @test JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatDelta}([delta1, delta2])) == JuLS.FloatDelta(5.0)
    @test JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatDelta}([delta1, delta2, delta3])) ==
          JuLS.FloatDelta(15.0)
end

@testitem "Test eval 3" begin
    invariant = JuLS.ComparatorInvariant(-10.0)

    delta1 = JuLS.FloatDelta(-2.0)
    delta2 = JuLS.FloatDelta(-3.0)
    delta3 = JuLS.FloatDelta(-10.0)

    @test JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatDelta}([delta1, delta2])) == JuLS.FloatDelta(-5.0)
    @test JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatDelta}([delta1, delta2, delta3])) ==
          JuLS.FloatDelta(-10.0)
end

@testitem "Test eval 4" begin
    invariant = JuLS.ComparatorInvariant(10.0)

    delta1 = JuLS.FloatDelta(-2.0)
    delta2 = JuLS.FloatDelta(-3.0)
    delta3 = JuLS.FloatDelta(-10.0)

    @test iszero(JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatDelta}([delta1, delta2])))
    @test iszero(JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatDelta}([delta1, delta2, delta3])))
end

@testitem "Test eval full" begin
    invariant = JuLS.ComparatorInvariant(10.0)

    message1 = JuLS.FloatFullMessage(2.0)
    message2 = JuLS.FloatFullMessage(3.0)
    message3 = JuLS.FloatFullMessage(10.0)

    @test JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatFullMessage}([message1, message2])) ==
          JuLS.FloatFullMessage(0)
    @test JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatFullMessage}([message1, message2, message3])) ==
          JuLS.FloatFullMessage(5.0)



    delta1 = JuLS.FloatDelta(2.0)
    delta2 = JuLS.FloatDelta(3.0)
    delta3 = JuLS.FloatDelta(10.0)

    JuLS.commit!(invariant, JuLS.DAGMessagesVector{JuLS.FloatDelta}([delta1, delta2])) # check that it still works after a commit

    @test JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatFullMessage}([message1, message2])) ==
          JuLS.FloatFullMessage(0)
    @test JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatFullMessage}([message1, message2, message3])) ==
          JuLS.FloatFullMessage(5.0)
end

@testitem "Test commit! 1" begin
    invariant = JuLS.ComparatorInvariant(10.0)

    delta1 = JuLS.FloatDelta(2.0)
    delta2 = JuLS.FloatDelta(3.0)
    delta3 = JuLS.FloatDelta(10.0)

    JuLS.commit!(invariant, JuLS.DAGMessagesVector{JuLS.FloatDelta}([delta1, delta2]))

    @test invariant.current_value == 5.0

    @test iszero(JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatDelta}([delta1, delta2])))
    @test JuLS.eval(invariant, JuLS.DAGMessagesVector{JuLS.FloatDelta}([delta1, delta2, delta3])) ==
          JuLS.FloatDelta(10.0)

end

@testitem "Test commit! 2" begin
    invariant = JuLS.ComparatorInvariant(10.0)

    delta1 = JuLS.FloatDelta(-12.0)
    delta3 = JuLS.FloatDelta(11.0)

    JuLS.commit!(invariant, delta3)

    @test invariant.current_value == 11.0

    @test JuLS.eval(invariant, delta1) == JuLS.FloatDelta(-1.0)
end