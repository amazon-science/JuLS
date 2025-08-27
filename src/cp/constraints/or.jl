# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct IsDifferent <: CPConstraint

CPConstraint b = ⋃ x[i] 

"""
struct Or <: CPConstraint
    x::Vector{BoolVariable}
    b::BoolVariable
    not_assigned::IntDomain
    active::StateObject{Bool}

    function Or(x::Vector{BoolVariable}, b::BoolVariable, trailer::Trailer)
        not_assigned = IntDomain(trailer, length(x), 0)
        constraint = new(x, b, not_assigned, StateObject(true, trailer))
        add_on_domain_change!(constraint)
        return constraint
    end
end

function propagate!(constraint::Or, to_propagate::Set{CPConstraint})
    x = constraint.x
    b = constraint.b
    if isbound(b)
        if assigned_value(b)
            if length(constraint.not_assigned) == 1
                i = constraint.not_assigned.values[1]
                remove!(x[i].domain, false)
                set_value!(constraint.active, false)
                return true
            end
        else
            for var in x
                if remove!(var.domain, true)
                    trigger_domain_change!(to_propagate, var)
                end
                if isempty(var.domain)
                    return false
                end
            end
            set_value!(constraint.active, false)
            return true
        end
    end

    to_remove = Int[]
    for i in constraint.not_assigned
        if isbound(x[i])
            push!(to_remove, i)
            if assigned_value(x[i])
                prunedB = remove!(b.domain, false)
                if prunedB
                    trigger_domain_change!(to_propagate, b)
                end
                if isempty(b.domain)
                    return false
                end
                set_value!(constraint.active, false)
                return true
            end
        end
    end

    if remove!(constraint.not_assigned, to_remove)
        add_to_propagate!(to_propagate, [constraint])
    end

    if isempty(constraint.not_assigned)
        if remove!(b, true)
            trigger_domain_change!(to_propagate, b)
        end
        set_value!(constraint.active, false)
    end
    return true
end

function apply!(constraint::Or)
    if all(var -> isbound(var), constraint.x)
        if all(var -> !assigned_value(var), constraint.x)
            remove!(constraint.b.domain, true)
        else
            remove!(constraint.b.domain, false)
        end
        return true
    end
    return false
end

variables(constraint::Or) = [constraint.x..., constraint.b]

@testitem "Or()" begin
    trailer = JuLS.Trailer()
    x1 = JuLS.BoolVariable(trailer)
    x2 = JuLS.BoolVariable(trailer)
    x3 = JuLS.BoolVariable(trailer)
    x = [x1, x2, x3]
    b = JuLS.BoolVariable(trailer)
    constraint = JuLS.Or(x, b, trailer)

    @test constraint.not_assigned.values == [1, 2, 3]
    @test constraint.b == b
    @test constraint.x == x
end

@testitem "propagate!(::Or)" begin
    trailer = JuLS.Trailer()
    x1 = JuLS.BoolVariable(trailer)
    x2 = JuLS.BoolVariable(trailer)
    x3 = JuLS.BoolVariable(trailer)
    x = [x1, x2, x3]
    b = JuLS.BoolVariable(trailer)
    constraint = JuLS.Or(x, b, trailer)
    to_propagate = Set{JuLS.CPConstraint}()

    JuLS.assign!(x[1], true)
    @test JuLS.propagate!(constraint, to_propagate)
    @test JuLS.assigned_value(b)

    JuLS.restore_initial_state!(trailer)
    JuLS.assign!(b, false)
    @test JuLS.propagate!(constraint, to_propagate)
    @test !(JuLS.assigned_value(x[1]) || JuLS.assigned_value(x[2]) || JuLS.assigned_value(x[3]))

    JuLS.restore_initial_state!(trailer)
    JuLS.assign!(b, true)
    @test JuLS.propagate!(constraint, to_propagate)
    @test !JuLS.isbound(x[1]) && !JuLS.isbound(x[2]) && !JuLS.isbound(x[3])

    JuLS.restore_initial_state!(trailer)
    JuLS.assign!(b, false)
    JuLS.assign!(x[1], true)
    @test !JuLS.propagate!(constraint, to_propagate)

    JuLS.restore_initial_state!(trailer)
    JuLS.assign!(x[1], false)
    JuLS.assign!(x[2], false)
    JuLS.assign!(x[3], false)
    @test JuLS.propagate!(constraint, to_propagate)
    @test !JuLS.assigned_value(b)
    @test !JuLS.is_active(constraint)

    JuLS.restore_initial_state!(trailer)
    JuLS.assign!(b, true)
    JuLS.assign!(x[2], false)
    JuLS.assign!(x[3], false)
    @test JuLS.propagate!(constraint, to_propagate)
    @test 1 in constraint.not_assigned && !(2 in constraint.not_assigned) && !(3 in constraint.not_assigned)
    @test JuLS.propagate!(constraint, to_propagate)
    @test JuLS.assigned_value(x[1])
end

function Base.show(io::IO, constraint::Or)
    print(
        io,
        string(typeof(constraint)),
        ": ",
        id(constraint.b),
        " = ",
        join([id(var) for var in constraint.x], " ⩔ "),
        ", active = ",
        is_active(constraint),
    )
end

function Base.show(io::IO, ::MIME"text/plain", constraint::Or)
    print(
        io,
        string(typeof(constraint)),
        ": ",
        id(constraint.b),
        " = ",
        join([id(var) for var in constraint.x], " ⩔ "),
        ", active = ",
        is_active(constraint),
    )
end