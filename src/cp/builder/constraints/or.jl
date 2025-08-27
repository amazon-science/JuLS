# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    build!(::OrInvariant, 
           input_variables::Vector{CPVariable}, 
           trailer::Trailer, 
           id::Int)

Builds CPConstraint Or and its output BoolVariable b s.t. b = x_1 ∪ x_2 ∪ ... ∪ x_n from OrInvariant
"""
function build!(::OrInvariant, input_variables::Vector{CPVariable}, trailer::Trailer, id::Int)
    @assert all(var -> var isa BoolVariable, input_variables)

    output_variable = BoolVariable(id, trailer)
    return IntermediateCPVariableMessage(
        output_variable,
        Or(BoolVariable[input_variables...], output_variable, trailer),
    )
end

@testitem "build!(::OrInvariant)" begin
    invariant = JuLS.OrInvariant()

    trailer = JuLS.Trailer()
    x = JuLS.CPVariable[JuLS.BoolVariable(i, trailer) for i = 1:8]

    cp_message = JuLS.build!(invariant, x, trailer, 3)

    @test cp_message isa JuLS.IntermediateCPVariableMessage
    @test cp_message.variable isa JuLS.BoolVariable
    @test cp_message.variable.id == 3
    @test cp_message.inner_constraint isa JuLS.Or
    @test cp_message.inner_constraint.x == x
    @test cp_message.inner_constraint.b == cp_message.variable
end