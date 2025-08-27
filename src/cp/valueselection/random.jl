# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct RandomValueSelection <: AbstractValueSelection

Value selection heuristic. Returns a random domain value of variable selected.
"""
struct RandomValueSelection <: AbstractValueSelection
    rng::Union{Nothing,AbstractRNG}
end
RandomValueSelection() = RandomValueSelection(nothing)


function (value_selection::RandomValueSelection)(
    run::Union{Nothing,CPRun} = nothing,
    x::Union{Nothing,CPVariable} = nothing,
)
    if isnothing(value_selection.rng)
        return rand(x.domain.values[1:x.domain.size.value]) + x.domain.offset
    end
    return rand(value_selection.rng, x.domain.values[1:x.domain.size.value]) + x.domain.offset
end

@testitem "(::RandomValueSelection)()" begin
    using Random
    rng = MersenneTwister(0)

    trailer = JuLS.Trailer()
    run = JuLS.CPRun(trailer)
    x1 = JuLS.IntVariable(1, 4, 9, trailer)
    x2 = JuLS.IntVariable(2, 3, 5, trailer)
    x3 = JuLS.IntVariable(3, 6, 6, trailer)
    JuLS.add_variable!(run, x1)
    JuLS.add_variable!(run, x2)
    JuLS.add_variable!(run, x3)

    h = JuLS.RandomValueSelection(rng)
    @test h(run, x1) == 4
end