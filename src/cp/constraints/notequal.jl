# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct NotEqual <: CPConstraint
CPConstraint x != y between two CPVariables `x` and `y`.
"""
struct NotEqual <: CPConstraint
    x::CPVariable
    y::CPVariable
    active::StateObject{Bool}

    function NotEqual(x::CPVariable, y::CPVariable, trailer::Trailer)
        constraint = new(x, y, StateObject(true, trailer))
        add_on_domain_change!(constraint)
        return constraint
    end
end

function propagate!(constraint::NotEqual, to_propagate::Set{CPConstraint})

    if isempty(constraint.x.domain) || isempty(constraint.y.domain)
        return false
    end
    if isbound(constraint.x)
        set_value!(constraint.active, false)
        pruned = remove!(constraint.y.domain, maximum(constraint.x.domain))
        if isempty(constraint.y.domain)
            return false
        end
        if pruned
            trigger_domain_change!(to_propagate, constraint.y)
        end
        return true
    end
    if isbound(constraint.y)
        set_value!(constraint.active, false)
        pruned = remove!(constraint.x.domain, maximum(constraint.y.domain))
        if isempty(constraint.x.domain)
            return false
        end
        if pruned
            trigger_domain_change!(to_propagate, constraint.x)
        end
        return true
    end
    return true
end

variables(constraint::NotEqual) = [constraint.x, constraint.y]

@testitem "NotEqual" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 4, trailer)
    y = JuLS.IntVariable(2, 2, trailer)

    constraint = JuLS.NotEqual(x, y, trailer)
    to_propagate = Set{JuLS.CPConstraint}()

    @test JuLS.propagate!(constraint, to_propagate)
    @test !(2 in x.domain) && length(x.domain) == 3

    x2 = JuLS.IntVariable(1, 4, trailer)
    y2 = JuLS.IntVariable(3, 6, trailer)
    constraint2 = JuLS.NotEqual(x2, y2, trailer)
    @test JuLS.propagate!(constraint2, to_propagate)
    @test length(x2.domain) == 4
    @test (1 in x2.domain) && (2 in x2.domain) && (3 in x2.domain) && (4 in x2.domain)
end

@testitem "propagate!(::NotEqual)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 5, trailer)
    y = JuLS.IntVariable(3, 3, trailer)

    constraint = JuLS.NotEqual(x, y, trailer)
    to_propagate = Set{JuLS.CPConstraint}()

    @test JuLS.propagate!(constraint, to_propagate)
    @test !(3 in x.domain) && length(x.domain) == 4
    @test !JuLS.is_active(constraint)
end

@testitem "3 linked variables propagate!(::NotEqual)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 2, trailer)
    y = JuLS.IntVariable(2, 2, trailer)
    z = JuLS.IntVariable(2, 3, trailer)

    constraint1 = JuLS.NotEqual(x, y, trailer)
    constraint2 = JuLS.NotEqual(y, z, trailer)
    constraint3 = JuLS.NotEqual(x, z, trailer)

    to_propagate = Set{JuLS.CPConstraint}()
    @test JuLS.propagate!(constraint1, to_propagate)
    @test JuLS.propagate!(constraint2, to_propagate)
    @test JuLS.propagate!(constraint3, to_propagate)
    @test (1 in x.domain) && length(x.domain) == 1
    @test (2 in y.domain) && length(y.domain) == 1
    @test (3 in z.domain) && length(z.domain) == 1
    @test !JuLS.is_active(constraint1) && !JuLS.is_active(constraint2) && !JuLS.is_active(constraint3)
end

@testitem "Infeasible ::NotEqual" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, trailer)
    y = JuLS.IntVariable(1, 1, trailer)

    constraint = JuLS.NotEqual(x, y, trailer)
    to_propagate = Set{JuLS.CPConstraint}()

    @test !JuLS.propagate!(constraint, to_propagate)
end

