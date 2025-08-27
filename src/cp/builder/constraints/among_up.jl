# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    build!(among::AmongInvariant,
           comparator::ComparatorInvariant,
           input_variables::Vector{CPVariable},
           trailer::Trailer,
           ::Int)

Builds CPConstraint AmongUp from the composition of AmongInvariant and ComparatorInvariant.
"""
function build!(
    among::AmongInvariant,
    comparator::ComparatorInvariant,
    input_variables::Vector{CPVariable},
    trailer::Trailer,
    ::Int,
)
    if length(input_variables) <= comparator.original_capacity
        return NoMessage()
    end
    return CPConstraintMessage(AmongUp(input_variables, among.set, Int(floor(comparator.original_capacity)), trailer))
end

@testitem "build!(::AmongInvariant, ::ComparatorInvariant)" begin
    among = JuLS.AmongInvariant(JuLS.Interval(3, 7))
    comparator = JuLS.ComparatorInvariant(2)

    trailer = JuLS.Trailer()
    x = JuLS.CPVariable[JuLS.IntVariable(i, 2, 9, trailer) for i = 1:8]

    cp_message = JuLS.build!(among, comparator, x, trailer, 5)

    @test cp_message isa JuLS.CPConstraintMessage
    @test cp_message.constraint isa JuLS.AmongUp
    @test cp_message.constraint.set.inf == 3 && cp_message.constraint.set.sup == 7
    @test cp_message.constraint.x == x
    @test cp_message.constraint.cap == 2
end
