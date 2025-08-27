# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    build!(invariant::IsDifferentInvariant{IntDecisionValue},
           input_variables::Vector{CPVariable},
           trailer::Trailer,
           id::Int)

Builds CPConstraint IsDifferent and its output BoolVariable b s.t. b = (x != v) from IsDifferentInvariant
"""
function build!(
    invariant::IsDifferentInvariant{IntDecisionValue},
    input_variables::Vector{CPVariable},
    trailer::Trailer,
    id::Int,
)
    @assert length(input_variables) == 1 "IsDifferentInvariant can only have one input variable"
    x = input_variables[1]
    output_variable = BoolVariable(id, trailer)

    return IntermediateCPVariableMessage(
        output_variable,
        IsDifferent(x, invariant.value.value, output_variable, trailer),
    )
end


@testitem "build!(::IsDifferentInvariant{IntDecisionValue}" begin
    invariant = JuLS.IsDifferentInvariant(JuLS.IntDecisionValue(1))

    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 4, trailer)

    cp_message = JuLS.build!(invariant, JuLS.CPVariable[x], trailer, 4)

    @test cp_message isa JuLS.IntermediateCPVariableMessage
    @test cp_message.variable isa JuLS.BoolVariable
    @test cp_message.variable.id == 4
    @test cp_message.inner_constraint isa JuLS.IsDifferent
    @test cp_message.inner_constraint.v == 1
    @test cp_message.inner_constraint.x == x
    @test cp_message.inner_constraint.b == cp_message.variable
end