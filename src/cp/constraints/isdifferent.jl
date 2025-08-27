# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct IsDifferent <: CPConstraint

CPConstraint b ⟺ x ≠ v

"""
struct IsDifferent <: CPConstraint
    x::CPVariable
    v::Int
    b::BoolVariable
    active::StateObject{Bool}

    function IsDifferent(x::CPVariable, v::Int, b::BoolVariable, trailer::Trailer)
        constraint = new(x, v, b, StateObject(true, trailer))
        add_on_domain_change!(constraint)
        return constraint
    end
end

function propagate!(constraint::IsDifferent, to_propagate::Set{CPConstraint})
    x = constraint.x
    b = constraint.b
    v = constraint.v

    if !isbound(b)
        prunedB = false
        if !(v in x.domain)
            prunedB = remove!(b.domain, false)
            set_value!(constraint.active, false)
        elseif isbound(x) && assigned_value(x) == v
            prunedB = remove!(b.domain, true)
            set_value!(constraint.active, false)
        end

        if prunedB
            trigger_domain_change!(to_propagate, b)
        end

        return true
    end

    pruned_x = false
    if assigned_value(b)
        pruned_x = remove!(x.domain, v)
    else
        pruned_x = remove_all_but!(x.domain, v)
    end

    if pruned_x
        trigger_domain_change!(to_propagate, x)
    end

    set_value!(constraint.active, false)

    return !isempty(x.domain)
end

variables(constraint::IsDifferent) = [constraint.x, constraint.b]

function apply!(constraint::IsDifferent)
    if isbound(constraint.x)
        if constraint.v != assigned_value(constraint.x)
            remove!(constraint.b.domain, false)
        else
            remove!(constraint.b.domain, true)
        end
        return true
    end
    return false
end

@testitem "propagate!(::IsDifferent)" begin
    trailer = JuLS.Trailer()
    b = JuLS.BoolVariable(trailer)
    x = JuLS.IntVariable(1, 4, trailer)
    v = 3
    constraint = JuLS.IsDifferent(x, v, b, trailer)
    to_propagate = Set{JuLS.CPConstraint}()

    JuLS.assign!(x, 3)
    @test JuLS.propagate!(constraint, to_propagate)
    @test !JuLS.assigned_value(b)

    JuLS.restore_initial_state!(trailer)
    JuLS.remove!(x, 3)
    @test JuLS.propagate!(constraint, to_propagate)
    @test JuLS.assigned_value(b)

    JuLS.restore_initial_state!(trailer)
    JuLS.remove!(b, true)
    @test JuLS.propagate!(constraint, to_propagate)
    @test JuLS.assigned_value(x) == 3

    JuLS.restore_initial_state!(trailer)
    JuLS.remove!(b, false)
    @test JuLS.propagate!(constraint, to_propagate)
    @test !(3 in x.domain)
end


function Base.show(io::IO, constraint::IsDifferent)
    print(
        io,
        string(typeof(constraint)),
        ": ",
        id(constraint.b),
        " = (",
        id(constraint.x),
        " != ",
        constraint.v,
        ")",
        ", active = ",
        is_active(constraint),
    )
end

function Base.show(io::IO, ::MIME"text/plain", constraint::IsDifferent)
    print(
        io,
        string(typeof(constraint)),
        ": ",
        id(constraint.b),
        " = (",
        id(constraint.x),
        " != ",
        constraint.v,
        ")",
        ", active = ",
        is_active(constraint),
    )
end