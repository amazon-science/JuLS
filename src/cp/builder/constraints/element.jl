# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    build!(invariant::ElementInvariant{IntDecisionValue}, 
           input_variables::Vector{CPVariable}, 
           trailer::Trailer, 
           id::Int)

Builds CPConstraint ElementBC and its output IntVariable y s.t. y = vec[x] from ElementInvariant
Only one input variable is allowed here.
"""
function build!(
    invariant::ElementInvariant{IntDecisionValue},
    input_variables::Vector{CPVariable},
    trailer::Trailer,
    id::Int,
)
    @assert length(input_variables) == 1 "ElementInvariant can only have one input variable"
    x = input_variables[1]

    vec = [e.value for e in invariant.elements]

    if isbound(x)
        y_value = vec[assigned_value(x)]
        return CPVariableMessage(IntVariable(id, y_value, y_value, trailer))
    end
    y_values = unique(vec)

    y = IntVariable(id, y_values, trailer)

    return IntermediateCPVariableMessage(y, ElementBC(vec, x, y, trailer))
end

@testitem "build!(::ElementInvariant)" begin

    invariant = JuLS.ElementInvariant(3, [JuLS.IntDecisionValue(1), JuLS.IntDecisionValue(4), JuLS.IntDecisionValue(3)])

    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 3, trailer)

    cp_message = JuLS.build!(invariant, JuLS.CPVariable[x], trailer, 2)

    @test cp_message isa JuLS.IntermediateCPVariableMessage
    @test cp_message.variable.id == 2
    @test cp_message.variable.domain.values == [1, 3, 4]
    @test cp_message.inner_constraint isa JuLS.ElementBC
    @test cp_message.inner_constraint.vec == [1, 4, 3]

    z = JuLS.IntVariable(1, 1, 3, trailer)

    @test_throws AssertionError JuLS.build!(invariant, JuLS.CPVariable[x, z], trailer, 2)
end