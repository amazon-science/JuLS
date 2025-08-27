# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct RandomVariableSelection <: AbstractVariableSelection

Variable selection heuristic. Returns a random variable among not assigned ones.
"""

struct RandomVariableSelection <: AbstractVariableSelection
    rng::Union{Nothing,AbstractRNG}
end
RandomVariableSelection() = RandomVariableSelection(nothing)


function (variable_selection::RandomVariableSelection)(cpmodel::CPRun)
    acceptable_indexes = Int[]
    for (idx, x) in enumerate(cpmodel.branchable_variables)
        if !isbound(x)
            push!(acceptable_indexes, idx)
        end
    end
    if !isnothing(variable_selection.rng)
        return cpmodel.branchable_variables[acceptable_indexes[rand(
            variable_selection.rng,
            1:length(acceptable_indexes),
        )]]
    end
    cpmodel.branchable_variables[acceptable_indexes[rand(1:length(acceptable_indexes))]]
end

@testitem "(::RandomVariableSelection)()" begin
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

    h = JuLS.RandomVariableSelection(rng)
    @test h(run) == x1
end