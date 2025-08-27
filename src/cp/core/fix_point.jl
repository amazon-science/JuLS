# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    fix_point!(run::CPRun, new_constraints=nothing)

Run the fix-point algorithm. Will prune the domain of every variable linked to `constraints` as much as possible, using its constraints.
Return true if the problem is still feasible. 

# Arguments
- `run::CPRun`: the model you want to apply the algorithm on.
- `new_constraints::Union{Array{CPConstraint}, Nothing}`: if this is filled with a set of constraints, 
only those will be propagated in the first place. Otherwise all the constraints will be propagated.
"""
function fix_point!(run::CPRun, new_constraints::Union{Array{CPConstraint},Nothing} = nothing)
    isnothing(new_constraints) ? fix_point!(run.constraints) : fix_point!(new_constraints)
end
function fix_point!(constraints::Array{CPConstraint})
    to_propagate = Set{CPConstraint}()

    add_to_propagate!(to_propagate, constraints)
    while !isempty(to_propagate)
        constraint = pop!(to_propagate)
        if !propagate!(constraint, to_propagate)
            return false
        end
    end
    return true
end

@testitem "fix_point!()" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(2, 6, trailer)
    y = JuLS.IntVariable(5, 8, trailer)
    z = JuLS.IntVariable(6, 15, trailer)
    t = JuLS.IntVariable(6, 10, trailer)
    u = JuLS.IntVariable(10, 25, trailer)

    constraint = JuLS.Equal(x, y, trailer)

    constraint3 = JuLS.Equal(z, t, trailer)

    run = JuLS.CPRun(trailer)

    JuLS.add_constraint!(run, constraint)
    JuLS.add_constraint!(run, constraint3)

    feasability = JuLS.fix_point!(run)


    @test feasability

    @test length(x.domain) == 2
    @test length(y.domain) == 2
    @test length(z.domain) == 5
    @test length(t.domain) == 5

    constraint2 = JuLS.Equal(y, z, trailer)

    JuLS.add_constraint!(run, constraint2)

    JuLS.fix_point!(JuLS.CPConstraint[constraint2])


    @test JuLS.isbound(x)
    @test JuLS.isbound(y)
    @test JuLS.isbound(z)
    @test JuLS.isbound(t)

    constraint4 = JuLS.Equal(u, z, trailer)
    JuLS.add_constraint!(run, constraint4)

    feasability2 = JuLS.fix_point!(JuLS.CPConstraint[constraint4])
    @test !feasability2
end