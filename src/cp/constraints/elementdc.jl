# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct ElementDC <: CPConstraint

CPConstraint vec[x] = y. Domain consistency propagation

"""
struct ElementDC <: CPConstraint
    vec::Vector{Int}
    x::CPVariable
    y::CPVariable

    active::StateObject{Bool}
end

function ElementDC(vec::Vector{Int}, x::CPVariable, y::CPVariable, trailer::Trailer)
    constraint = ElementDC(vec, x, y, StateObject{Bool}(true, trailer))

    add_on_domain_change!(constraint)

    return constraint
end

function propagate!(constraint::ElementDC, to_propagate::Set{CPConstraint})
    if isbound(constraint.x)
        pruned_y = remove_all_but!(constraint.y.domain, constraint.vec[assigned_value(constraint.x)])
        if isempty(constraint.y.domain)
            return false
        end
        set_value!(constraint.active, false)
        if pruned_y
            trigger_domain_change!(to_propagate, constraint.y)
        end
        return true
    end

    supported = falses(length(constraint.y.domain))
    pruned_x = Int[]
    for i in constraint.x.domain
        if !(constraint.vec[i] in constraint.y.domain)
            push!(pruned_x, i)
        else
            supported[get_value_support_index(constraint.y.domain, constraint.vec[i])] = true
        end
    end

    if !isempty(pruned_x)
        remove!(constraint.x.domain, pruned_x)
        trigger_domain_change!(to_propagate, constraint.x)
    end

    pruned_y = Int[]
    for (j, v) in enumerate(constraint.y.domain)
        if !supported[j]
            push!(pruned_y, v)
        end
    end

    if !isempty(pruned_y)
        remove!(constraint.y.domain, pruned_y)
        trigger_domain_change!(to_propagate, constraint.y)
    end

    if isbound(constraint.y)
        set_value!(constraint.active, false)
    end

    return !isempty(constraint.x.domain) && !isempty(constraint.y.domain)
end


function get_value_support_index(domain::IntDomain, value::Int)
    return domain.indexes[value-domain.offset]
end

function apply!(constraint::ElementDC)
    if isbound(constraint.x)
        v = constraint.vec[assigned_value(constraint.x)]
        remove_all_but!(constraint.y.domain, v)

        return true
    end
    return false
end


variables(constraint::ElementDC) = [constraint.x, constraint.y]

@testitem "ElementDC()" begin
    trailer = JuLS.Trailer()

    x = JuLS.IntVariable(1, 5, trailer)

    y_values = [3, 8, 9, 1]
    dom = JuLS.IntDomain(trailer, y_values)
    y = JuLS.IntVariable(0, dom, JuLS.CPConstraint[])

    vec = [1, 16, 3, 16, 9]

    constraint = JuLS.ElementDC(vec, x, y, trailer)

    @test constraint.vec == [1, 16, 3, 16, 9]

    @test constraint in x.on_domain_change
end

@testitem "propagate!(::ElementDC)" begin
    trailer = JuLS.Trailer()

    x = JuLS.IntVariable(1, 5, trailer)

    y_values = [3, 8, 9, 1]
    dom = JuLS.IntDomain(trailer, y_values)
    y = JuLS.IntVariable(0, dom, JuLS.CPConstraint[])

    vec = [1, 16, 3, 8, 9]

    constraint = JuLS.ElementDC(vec, x, y, trailer)
    to_propagate = Set{JuLS.CPConstraint}()

    JuLS.assign!(x, 3)

    @test JuLS.propagate!(constraint, to_propagate)

    @test JuLS.isbound(y) && JuLS.assigned_value(y) == 3

    JuLS.restore_initial_state!(trailer)
    JuLS.remove!(x, 4)

    # Domain consistency : 8 not in D(y)
    @test JuLS.propagate!(constraint, to_propagate)
    @test !(8 in y.domain)
end

function Base.show(io::IO, constraint::ElementDC)
    print(
        io,
        string(typeof(constraint)),
        ": ",
        "vec[$(id(constraint.x))] = $(id(constraint.y))",
        ", vec = $(constraint.vec)",
        ", active = ",
        is_active(constraint),
    )
end

function Base.show(io::IO, ::MIME"text/plain", constraint::ElementDC)
    print(
        io,
        string(typeof(constraint)),
        ": ",
        "vec[$(id(constraint.x))] = $(id(constraint.y))",
        ", vec = $(constraint.vec)",
        ", active = ",
        is_active(constraint),
    )
end