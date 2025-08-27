# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    AggregatorInvariant <: Invariant

Invariant to aggregate the deltas present in the input array, either ObjectiveDelta
or ConstraintDelta into a ResultDelta, containing the sum of all and if solution is
feasible.
"""
mutable struct AggregatorInvariant <: Invariant
    current_constraint::Float64
end

InputType(::AggregatorInvariant) = MultiType()

AggregatorInvariant() = AggregatorInvariant(0.0)
eval(invariant::AggregatorInvariant, ::NoMessage) = ResultDelta(0.0, iszero(invariant.current_constraint))

eval(invariant::AggregatorInvariant) = ResultDelta(0.0, invariant.current_constraint == 0.0)

eval(invariant::AggregatorInvariant, messages::MultiTypedDAGMessages{<:Delta}) =
    eval(invariant, sum(messages[ObjectiveDelta]), sum(messages[ConstraintDelta]))
eval(invariant::AggregatorInvariant, objective::ObjectiveDelta, constraint::ConstraintDelta) =
    ResultDelta(objective.value + constraint.value, iszero(invariant.current_constraint + constraint.value))

eval(invariant::AggregatorInvariant, messages::MultiTypedDAGMessages{<:FullMessage}) =
    eval(invariant, sum(messages[ObjectiveFullMessage]), sum(messages[ConstraintFullMessage]))
eval(::AggregatorInvariant, objective::ObjectiveFullMessage, constraint::ConstraintFullMessage) =
    ResultMessage(objective.value + constraint.value, constraint.value, iszero(constraint.value))

commit!(invariant::AggregatorInvariant, messages::MultiTypedDAGMessages{<:Delta}) =
    (invariant.current_constraint += sum(messages[ConstraintDelta]).value)

function init!(invariant::AggregatorInvariant, messages::MultiTypedDAGMessages{<:FullMessage})
    invariant.current_constraint = sum(messages[ConstraintFullMessage]).value
    return eval(invariant, messages)
end

@testitem "Test constructor" begin
    invariant = JuLS.AggregatorInvariant()

    @test invariant.current_constraint == 0.0
end

@testitem "Test eval without message" begin
    invariant = JuLS.AggregatorInvariant(10.0)

    @test JuLS.eval(invariant) == JuLS.ResultDelta(0.0, false)
end

@testitem "eval(::FullMessage)" begin
    invariant = JuLS.AggregatorInvariant()

    delta1 = JuLS.ObjectiveFullMessage(10.0)
    delta2 = JuLS.ConstraintFullMessage(2.0)
    delta3 = JuLS.ObjectiveFullMessage(-2.0)
    delta4 = JuLS.ConstraintFullMessage(-1.0)

    lazy_messages = JuLS.DAGMessage[]
    push!(lazy_messages, delta1)
    push!(lazy_messages, delta2)
    input = JuLS.MultiTypedDAGMessages(lazy_messages)

    @test JuLS.eval(invariant, JuLS.MultiTypedDAGMessages([delta1])) == JuLS.ResultMessage(10.0, 0.0, true)
    @test JuLS.eval(invariant, JuLS.MultiTypedDAGMessages([delta2])) == JuLS.ResultMessage(2.0, 2.0, false)
    @test JuLS.eval(invariant, input) == JuLS.ResultMessage(12.0, 2.0, false)

    lazy_messages = JuLS.DAGMessage[]
    push!(lazy_messages, delta2)
    push!(lazy_messages, delta4)
    input = JuLS.MultiTypedDAGMessages(lazy_messages)

    @test JuLS.eval(invariant, input) == JuLS.ResultMessage(1.0, 1.0, false)

    lazy_messages = JuLS.DAGMessage[]
    push!(lazy_messages, delta1)
    push!(lazy_messages, delta3)
    input = JuLS.MultiTypedDAGMessages(lazy_messages)

    @test JuLS.eval(invariant, input) == JuLS.ResultMessage(8.0, 0.0, true)

    delta1 = JuLS.ObjectiveFullMessage(10.0)
    delta2 = JuLS.ConstraintFullMessage(0.0)

    lazy_messages = JuLS.DAGMessage[]
    push!(lazy_messages, delta1)
    push!(lazy_messages, delta2)
    input = JuLS.MultiTypedDAGMessages(lazy_messages)

    @test JuLS.eval(invariant, JuLS.MultiTypedDAGMessages([delta2])) == JuLS.ResultMessage(0.0, 0.0, true)
    @test JuLS.eval(invariant, input) == JuLS.ResultMessage(10.0, 0.0, true)
end

@testitem "Test eval" begin
    invariant = JuLS.AggregatorInvariant()

    delta1 = JuLS.ObjectiveDelta(10.0)
    delta2 = JuLS.ConstraintDelta(2.0)

    lazy_messages = JuLS.DAGMessage[]
    push!(lazy_messages, delta1)
    push!(lazy_messages, delta2)
    input = JuLS.MultiTypedDAGMessages(lazy_messages)

    @test JuLS.eval(invariant, input) == JuLS.ResultDelta(12.0, false)
end

@testitem "Test eval 2" begin
    invariant = JuLS.AggregatorInvariant(2)

    delta1 = JuLS.ObjectiveDelta(10.0)
    delta2 = JuLS.ConstraintDelta(-2.0)

    lazy_messages = JuLS.DAGMessage[]
    push!(lazy_messages, delta1)
    push!(lazy_messages, delta2)
    input = JuLS.MultiTypedDAGMessages(lazy_messages)

    @test JuLS.eval(invariant, input) == JuLS.ResultDelta(8.0, true)
end

@testitem "Test eval 3" begin
    invariant = JuLS.AggregatorInvariant(0)

    delta1 = JuLS.ObjectiveDelta(10.0)
    delta2 = JuLS.ConstraintDelta(1.0e-9)
    delta3 = JuLS.ObjectiveDelta(-3.0)
    delta4 = JuLS.ConstraintDelta(-1.0e-9)

    @test JuLS.eval(invariant, JuLS.MultiTypedDAGMessages([delta1])) == JuLS.ResultDelta(10.0, true)
    @test JuLS.eval(invariant, JuLS.MultiTypedDAGMessages([delta2])) == JuLS.ResultDelta(1.0e-9, false)

    lazy_messages = JuLS.DAGMessage[]
    push!(lazy_messages, delta1)
    push!(lazy_messages, delta3)
    input = JuLS.MultiTypedDAGMessages(lazy_messages)

    @test JuLS.eval(invariant, input) == JuLS.ResultDelta(7.0, true)

    lazy_messages = JuLS.DAGMessage[]
    push!(lazy_messages, delta2)
    push!(lazy_messages, delta4)
    input = JuLS.MultiTypedDAGMessages(lazy_messages)

    @test JuLS.eval(invariant, input) == JuLS.ResultDelta(0.0, true)
end

@testitem "Test commit!" begin
    invariant = JuLS.AggregatorInvariant()

    delta1 = JuLS.ObjectiveDelta(10.0)
    delta2 = JuLS.ConstraintDelta(2.0)

    lazy_messages = JuLS.DAGMessage[]
    push!(lazy_messages, delta1)
    push!(lazy_messages, delta2)
    input = JuLS.MultiTypedDAGMessages(lazy_messages)

    JuLS.commit!(invariant, input)

    @test invariant.current_constraint == 2.0
end

@testitem "Testing eval and commit! with no message" begin
    invariant = JuLS.AggregatorInvariant()
    @test JuLS.eval(invariant, JuLS.NoMessage()) == JuLS.ResultDelta(0.0, true)

    invariant = JuLS.AggregatorInvariant(10.0)
    @test JuLS.eval(invariant, JuLS.NoMessage()) == JuLS.ResultDelta(0.0, false)

    JuLS.commit!(invariant, JuLS.NoMessage())
    @test JuLS.eval(invariant, JuLS.NoMessage()) == JuLS.ResultDelta(0.0, false)
end

@testitem "init!(::AggregatorInvariant)" begin
    invariant = JuLS.AggregatorInvariant()

    delta1 = JuLS.ObjectiveFullMessage(10.0)
    delta2 = JuLS.ConstraintFullMessage(4.0)

    lazy_messages = JuLS.DAGMessage[]
    push!(lazy_messages, delta1)
    push!(lazy_messages, delta2)
    input = JuLS.MultiTypedDAGMessages(lazy_messages)

    @test JuLS.init!(invariant, input) == JuLS.ResultMessage(14.0, 4.0, false)
    @test invariant.current_constraint == 4.0
end