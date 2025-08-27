# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    build!(invariant::RelationalInvariant{IntDecisionValue, NeOp},
           input_variables::Vector{CPVariable},
           trailer::Trailer,
           id::Int)

Builds CPConstraint NotEqual and its output BoolVariable b s.t. b = (x != v) from IsDifferentInvariant
"""
function build!(
    ::RelationalInvariant{IntDecisionValue,NeOp},
    input_variables::Vector{CPVariable},
    trailer::Trailer,
    ::Int,
)
    @assert length(input_variables) == 2 "RelationalInvariant can only have 2 input variable"
    x = input_variables[1]
    y = input_variables[2]

    return CPConstraintMessage(NotEqual(x, y, trailer))
end

@testitem "build!(::RelationalInvariant{IntDecisionValue,NeOp}" begin
    invariant = JuLS.RelationalInvariant{JuLS.IntDecisionValue,JuLS.NeOp}()

    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 4, trailer)
    y = JuLS.IntVariable(3, 7, trailer)

    cp_message = JuLS.build!(invariant, JuLS.CPVariable[x, y], trailer, 4)

    @test cp_message isa JuLS.CPConstraintMessage

    @test cp_message.constraint isa JuLS.NotEqual
    @test cp_message.constraint.x == x
    @test cp_message.constraint.y == y
end

