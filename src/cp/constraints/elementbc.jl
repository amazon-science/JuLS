# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct ElementBC <: CPConstraint

CPConstraint vec[x] = y. Bound consistency propagation

"""
struct ElementBC <: CPConstraint
    vec::Vector{Int}
    x::CPVariable
    y::CPVariable
    low::StateObject{Int}
    up::StateObject{Int}
    xy::Vector{Tuple{Int,Int}}
    active::StateObject{Bool}
end

function ElementBC(vec::Vector{Int}, x::CPVariable, y::CPVariable, trailer::Trailer)
    n = length(vec)
    xy = Vector{Tuple{Int,Int}}()
    for i = 1:n
        push!(xy, (i, vec[i]))
    end
    sort!(xy, by = xy -> xy[2])
    low = StateObject{Int}(1, trailer)
    up = StateObject{Int}(n, trailer)

    constraint = ElementBC(vec, x, y, low, up, xy, StateObject{Bool}(true, trailer))

    add_on_domain_change!(constraint)

    return constraint
end

function propagate!(constraint::ElementBC, to_propagate::Set{CPConstraint})
    # get useful variables
    low = constraint.low.value
    up = constraint.up.value
    y_min = minimum(constraint.y.domain)
    y_max = maximum(constraint.y.domain)
    xy = constraint.xy

    # update the supports of the cols and the rows and prune X if no supports
    # lower bound
    pruned_x = false
    while xy[low][2] < y_min || !(xy[low][1] in constraint.x.domain)
        if remove!(constraint.x.domain, xy[low][1])
            pruned_x = true
        end

        low += 1
        # @assert low <= up
        if low > up
            return false
        end
    end

    # upper bound
    while xy[up][2] > y_max || !(xy[up][1] in constraint.x.domain)
        if remove!(constraint.x.domain, xy[up][1])
            pruned_x = true
        end
        up -= 1
        # @assert low <= up
        if low > up
            return false
        end
    end

    # try to prune lower or upper values of y's domain
    pruned_y1 = remove_below!(constraint.y.domain, xy[low][2])
    pruned_y2 = remove_above!(constraint.y.domain, xy[up][2])

    # deactivate the constraint if necessary
    if isbound(constraint.x)
        set_value!(constraint.active, false)
    elseif isbound(constraint.y)
        vy = assigned_value(constraint.y)
        if all(vy == constraint.vec[vx] for vx in constraint.x.domain)
            set_value!(constraint.active, false)
        end
    end

    if pruned_x
        trigger_domain_change!(to_propagate, constraint.x)
    end

    if pruned_y1 || pruned_y2
        trigger_domain_change!(to_propagate, constraint.y)
    end

    # update useful variables
    set_value!(constraint.low, low)
    set_value!(constraint.up, up)

    # check feasibility
    return !isempty(constraint.x.domain) && !isempty(constraint.y.domain)
end

function apply!(constraint::ElementBC)
    if isbound(constraint.x)
        v = constraint.vec[assigned_value(constraint.x)]
        remove_all_but!(constraint.y.domain, v)
        return true
    end
    return false
end

variables(constraint::ElementBC) = [constraint.x, constraint.y]

@testitem "ElementBC()" begin
    trailer = JuLS.Trailer()

    x = JuLS.IntVariable(1, 5, trailer)

    y_values = [3, 8, 9, 1]
    dom = JuLS.IntDomain(trailer, y_values)
    y = JuLS.IntVariable(0, dom, JuLS.CPConstraint[])

    vec = [1, 16, 3, 16, 9]

    constraint = JuLS.ElementBC(vec, x, y, trailer)

    @test constraint.vec == [1, 16, 3, 16, 9]
    @test constraint.low.value == 1
    @test constraint.up.value == 5

    @test constraint.xy == [(1, 1), (3, 3), (5, 9), (2, 16), (4, 16)]
    @test constraint in x.on_domain_change
end

@testitem "propagate!(::ElementBC)" begin
    trailer = JuLS.Trailer()

    x = JuLS.IntVariable(1, 5, trailer)

    y_values = [3, 8, 9, 1]
    dom = JuLS.IntDomain(trailer, y_values)
    y = JuLS.IntVariable(0, dom, JuLS.CPConstraint[])

    vec = [1, 16, 3, 8, 9]

    constraint = JuLS.ElementBC(vec, x, y, trailer)
    to_propagate = Set{JuLS.CPConstraint}()

    JuLS.assign!(x, 3)

    @test JuLS.propagate!(constraint, to_propagate)

    @test JuLS.isbound(y) && JuLS.assigned_value(y) == 3

    JuLS.restore_initial_state!(trailer)
    JuLS.remove!(x, 4)

    # Bound consistency : 8 is still in D(y)
    @test JuLS.propagate!(constraint, to_propagate)
    @test 8 in y.domain
end

function Base.show(io::IO, constraint::ElementBC)
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

function Base.show(io::IO, ::MIME"text/plain", constraint::ElementBC)
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