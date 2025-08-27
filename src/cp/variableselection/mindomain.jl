# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct MinDomainVariableSelection <: AbstractVariableSelection

Variable selection heuristic. Returns the variable with smallest domain.
"""

struct MinDomainVariableSelection <: AbstractVariableSelection end

function (::MinDomainVariableSelection)(cpmodel::CPRun)
    selected_var = nothing
    min_size = typemax(Int)
    for x in cpmodel.branchable_variables
        if !isbound(x) && length(x.domain) < min_size
            selected_var = x
            min_size = length(x.domain)
        end
    end
    return selected_var
end

@testitem "(::MinDomainVariableSelection)()" begin
    trailer = JuLS.Trailer()
    run = JuLS.CPRun(trailer)
    x1 = JuLS.IntVariable(1, 4, 9, trailer)
    x2 = JuLS.IntVariable(2, 3, 5, trailer)
    x3 = JuLS.IntVariable(3, 6, 12, trailer)
    JuLS.add_variable!(run, x1)
    JuLS.add_variable!(run, x2)
    JuLS.add_variable!(run, x3)

    h = JuLS.MinDomainVariableSelection()
    @test h(run) == x2
end
