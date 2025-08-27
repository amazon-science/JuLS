# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    ScalarProductInvariant <: Invariant

Invariant to represent the scalar product 
y = (w | x)
"""
struct ScalarProductInvariant <: SummableEvalInvariant
    weights::Array{Float64}
end

eval(invariant::ScalarProductInvariant, delta::SingleVariableMoveDelta{BinaryDecisionValue}) =
    FloatDelta((delta.new_value.value - delta.current_value.value) * invariant.weights[delta.index])
eval(invariant::ScalarProductInvariant, m::SingleVariableMessage{BinaryDecisionValue}) =
    FloatFullMessage(m.value.value * invariant.weights[m.index])

commit!(::ScalarProductInvariant, ::SingleVariableMoveDelta{BinaryDecisionValue}) = nothing

@testitem "Test constructor" begin
    invariant = JuLS.ScalarProductInvariant([1.0, 2.0, 3.0])

    @test invariant.weights == [1.0, 2.0, 3.0]
end

@testitem "Test eval" begin
    invariant = JuLS.ScalarProductInvariant([1.0, 2.0, 3.0])

    delta1 = JuLS.SingleVariableMoveDelta(1, JuLS.BinaryDecisionValue(false), JuLS.BinaryDecisionValue(true))
    delta2 = JuLS.SingleVariableMoveDelta(3, JuLS.BinaryDecisionValue(false), JuLS.BinaryDecisionValue(true))

    lazy_messages = JuLS.DAGMessage[]
    push!(lazy_messages, delta1)
    push!(lazy_messages, delta2)
    input = JuLS.DAGMessagesVector(lazy_messages)

    @test JuLS.eval(invariant, input) == JuLS.FloatDelta(4.0)
end

@testitem "Test eval full" begin
    invariant = JuLS.ScalarProductInvariant([1.0, 2.0, 3.0])

    message1 = JuLS.SingleVariableMessage{JuLS.BinaryDecisionValue}(1, JuLS.BinaryDecisionValue(true))
    message2 = JuLS.SingleVariableMessage{JuLS.BinaryDecisionValue}(2, JuLS.BinaryDecisionValue(false))
    message3 = JuLS.SingleVariableMessage{JuLS.BinaryDecisionValue}(3, JuLS.BinaryDecisionValue(false))

    lazy_messages = JuLS.DAGMessage[]
    push!(lazy_messages, message1)
    push!(lazy_messages, message2)
    push!(lazy_messages, message3)
    input = JuLS.DAGMessagesVector(lazy_messages)

    @test JuLS.eval(invariant, input) == JuLS.FloatFullMessage(1.0)
end

@testitem "Test eval 2" begin
    invariant = JuLS.ScalarProductInvariant([1.0, 2.0, -1.0])

    delta1 = JuLS.SingleVariableMoveDelta(1, JuLS.BinaryDecisionValue(false), JuLS.BinaryDecisionValue(false))
    delta2 = JuLS.SingleVariableMoveDelta(3, JuLS.BinaryDecisionValue(false), JuLS.BinaryDecisionValue(false))

    lazy_messages = JuLS.DAGMessage[]
    push!(lazy_messages, delta1)
    push!(lazy_messages, delta2)
    input = JuLS.DAGMessagesVector(lazy_messages)

    @test iszero(JuLS.eval(invariant, input))
end

@testitem "Test eval 3" begin
    invariant = JuLS.ScalarProductInvariant([1.0, 2.0, 3.0])

    delta1 = JuLS.SingleVariableMoveDelta(1, JuLS.BinaryDecisionValue(false), JuLS.BinaryDecisionValue(true))
    delta2 = JuLS.SingleVariableMoveDelta(3, JuLS.BinaryDecisionValue(false), JuLS.BinaryDecisionValue(true))

    lazy_messages = JuLS.DAGMessage[]
    push!(lazy_messages, delta1)
    push!(lazy_messages, delta2)
    input = JuLS.DAGMessagesVector(lazy_messages)

    @test JuLS.eval(invariant, input) == JuLS.FloatDelta(4.0)

    delta1 = JuLS.SingleVariableMoveDelta(1, JuLS.BinaryDecisionValue(true), JuLS.BinaryDecisionValue(false))
    delta2 = JuLS.SingleVariableMoveDelta(3, JuLS.BinaryDecisionValue(true), JuLS.BinaryDecisionValue(false))

    lazy_messages = JuLS.DAGMessage[]
    push!(lazy_messages, delta1)
    push!(lazy_messages, delta2)
    input = JuLS.DAGMessagesVector(lazy_messages)

    @test JuLS.eval(invariant, input) == JuLS.FloatDelta(-4.0)
end