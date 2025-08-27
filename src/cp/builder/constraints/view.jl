# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    build!(scale_invariant::ScaleInvariant,
           input_variables::Vector{CPVariable},
           ::Trailer,
           id::Int)

Builds CPVariable VarViewMul y s.t. y = α * x
Only one input variable here.
"""
function build!(scale_invariant::ScaleInvariant, input_variables::Vector{CPVariable}, ::Trailer, id::Int)
    @assert length(input_variables) == 1 "VarViewMul can only have one input variable"
    x = input_variables[1]
    output_variable = VarViewMul(id, x, Int(floor(scale_invariant.α)))
    return CPVariableMessage(output_variable)
end

@testitem "build!(::ScaleInvariant)" begin
    scale = JuLS.ScaleInvariant(8)

    trailer = JuLS.Trailer()
    x = JuLS.CPVariable[JuLS.IntVariable(1, 2, 9, trailer)]

    cp_message = JuLS.build!(scale, x, trailer, 5)

    @test cp_message isa JuLS.CPVariableMessage
    @test cp_message.variable.id == 5
    @test cp_message.variable isa JuLS.VarViewMul
    @test cp_message.variable.c == 8
end