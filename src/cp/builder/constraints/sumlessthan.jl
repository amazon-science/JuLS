# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    build!(comparator::ComparatorInvariant,
           input_variables::Vector{CPVariable},
           trailer::Trailer,
           ::Int)

Builds CPConstraint SumLessThan from ComparatorInvariant.
"""
build!(comparator::ComparatorInvariant, input_variables::Vector{CPVariable}, trailer::Trailer, ::Int) =
    CPConstraintMessage(SumLessThan(input_variables, Int(floor(comparator.original_capacity)), trailer))

@testitem "build!(::ComparatorInvariant" begin
    invariant = JuLS.ComparatorInvariant(5)

    trailer = JuLS.Trailer()
    x1 = JuLS.IntVariable(1, 4, trailer)
    x2 = JuLS.IntVariable(3, 6, trailer)
    x3 = JuLS.IntVariable(2, 9, trailer)
    x = JuLS.CPVariable[x1, x2, x3]

    cp_message = JuLS.build!(invariant, x, trailer, 4)

    @test cp_message isa JuLS.CPConstraintMessage

    @test cp_message.constraint isa JuLS.SumLessThan
    @test cp_message.constraint.upper == 5
    @test cp_message.constraint.x == x
end