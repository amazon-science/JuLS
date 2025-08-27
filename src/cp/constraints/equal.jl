# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct Equal <: CPConstraint

CPConstraint x = y

"""
struct Equal <: CPConstraint
    x::CPVariable
    y::CPVariable
    active::StateObject{Bool}

    function Equal(x::CPVariable, y::CPVariable, trailer::Trailer)
        constraint = new(x, y, StateObject(true, trailer))
        add_on_domain_change!(constraint)
        return constraint
    end
end

function propagate!(constraint::Equal, to_propagate::Set{CPConstraint})

    if prune_equal!(constraint.x, constraint.y)
        trigger_domain_change!(to_propagate, constraint.x)
    end

    if prune_equal!(constraint.y, constraint.x)
        trigger_domain_change!(to_propagate, constraint.y)
    end

    if constraint in to_propagate
        pop!(to_propagate, constraint)
    end

    if length(constraint.x.domain) <= 1
        set_value!(constraint.active, false)
    end

    return !(isempty(constraint.x.domain) || isempty(constraint.y.domain))
end

"""
    prune_equal!(x::CPVariable, y::CPVariable)

Remove the values from the domain of `x` that are not in the domain of `y`.
"""
function prune_equal!(x::CPVariable, y::CPVariable)
    toRemove = Int[]
    for val in x.domain
        if !(val in y.domain)
            push!(toRemove, val)
        end
    end
    return remove!(x.domain, toRemove)
end

variables(constraint::Equal) = [constraint.x, constraint.y]

@testitem "prune_equal!()" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(2, 6, trailer)
    y = JuLS.IntVariable(5, 8, trailer)

    JuLS.prune_equal!(y, x)

    @test length(y.domain) == 2
    @test !(8 in y.domain) && 5 in y.domain && 6 in y.domain
end

@testitem "propagate!(::Equal)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(2, 6, trailer)
    y = JuLS.IntVariable(5, 8, trailer)

    constraint = JuLS.Equal(x, y, trailer)
    to_propagate = Set{JuLS.CPConstraint}()

    @test JuLS.propagate!(constraint, to_propagate)

    @test length(x.domain) == 2
    @test length(y.domain) == 2
    @test !(2 in x.domain) && 5 in x.domain && 6 in x.domain
    @test !(8 in y.domain) && 5 in y.domain && 6 in y.domain

    # Propagation test
    z = JuLS.IntVariable(5, 6, trailer)
    constraint2 = JuLS.Equal(y, z, trailer)
    JuLS.propagate!(constraint2, to_propagate)

    # Domain not reduced => not propagation
    @test !(constraint in to_propagate)
    @test !(constraint2 in to_propagate)

    # Domain reduced => propagation
    JuLS.remove!(z.domain, 5)
    JuLS.propagate!(constraint2, to_propagate)
    @test constraint in to_propagate
    @test !(constraint2 in to_propagate)

    #Unfeasible test
    t = JuLS.IntVariable(15, 30, trailer)
    constraint3 = JuLS.Equal(z, t, trailer)
    @test !JuLS.propagate!(constraint3, to_propagate)
end