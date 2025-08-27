# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct MaxDomainValueSelection <: AbstractValueSelection

Value selection heuristic. Returns the maximum domain value of variable selected.
"""
struct MaxDomainValueSelection <: AbstractValueSelection end


function (value_selection::MaxDomainValueSelection)(
    run::Union{Nothing,CPRun} = nothing,
    x::Union{Nothing,CPVariable} = nothing,
)
    return maximum(x.domain)
end

@testitem "(::MaxDomainValueSelection)()" begin
    trailer = JuLS.Trailer()
    run = JuLS.CPRun(trailer)
    x1 = JuLS.IntVariable(1, 4, 9, trailer)
    x2 = JuLS.IntVariable(2, 3, 5, trailer)
    x3 = JuLS.IntVariable(3, 6, 12, trailer)
    JuLS.add_variable!(run, x1)
    JuLS.add_variable!(run, x2)
    JuLS.add_variable!(run, x3)

    h = JuLS.MaxDomainValueSelection()
    @test h(run, x3) == 12
end