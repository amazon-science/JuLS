# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct Among <: CPConstraint

CPConstraint |{x | D(x) ⊂ I}| = y

"""

struct Among <: CPConstraint
    x::Vector{CPVariable}
    y::IntVariable
    set::AbstractSet

    overlap_indexes::IntDomain
    low::StateObject{Int}
    up::StateObject{Int}
    active::StateObject{Bool}
end

function Among(x::Vector{CPVariable}, y::IntVariable, set::AbstractSet, trailer::Trailer)

    overlap_indexes = IntDomain(trailer, length(x), 0)
    low = StateObject{Int}(0, trailer)
    up = StateObject{Int}(length(x), trailer)
    active = StateObject{Bool}(true, trailer)

    constraint = Among(x, y, set, overlap_indexes, low, up, active)

    add_on_domain_change!(constraint)

    return constraint
end

function propagate!(constraint::Among, to_propagate::Set{CPConstraint})
    non_overlapping = Int[]
    low = constraint.low.value
    up = constraint.up.value

    for i in constraint.overlap_indexes
        var = constraint.x[i]
        if is_including(constraint.set, var.domain)
            low += 1
            push!(non_overlapping, i)
            continue
        end

        if !is_overlapping(constraint.set, var.domain)
            up -= 1
            push!(non_overlapping, i)
        end
    end

    set_value!(constraint.low, low)
    set_value!(constraint.up, up)
    remove!(constraint.overlap_indexes, non_overlapping)

    y = constraint.y

    pruned_min = remove_below!(y.domain, low)
    pruned_max = remove_above!(y.domain, up)
    if pruned_min || pruned_max
        if isempty(y.domain)
            return false
        end
        trigger_domain_change!(to_propagate, y)
    end

    # low == up ⟺ isempty(constraint.overlap_indexes)
    if low == up
        set_value!(constraint.active, false)
        return true
    end

    if low == maximum(y.domain)
        set_value!(constraint.active, false)
        for i in constraint.overlap_indexes
            var = constraint.x[i]

            if remove!(var.domain, constraint.set)
                trigger_domain_change!(to_propagate, var)
            end

            if isempty(var.domain)
                return false
            end
        end
        return true
    end

    if up == minimum(y.domain)
        set_value!(constraint.active, false)
        for i in constraint.overlap_indexes
            var = constraint.x[i]

            if remove_all_but!(var.domain, constraint.set)
                trigger_domain_change!(to_propagate, var)
            end

            if isempty(var.domain)
                return false
            end
        end
        return true
    end

    return true
end

variables(constraint::Among) = vcat(constraint.x, constraint.y)

@testitem "Among(::Interval)" begin
    trailer = JuLS.Trailer()

    x1 = JuLS.IntVariable(1, 3, trailer)
    x2 = JuLS.IntVariable(2, 7, trailer)
    x3 = JuLS.IntVariable(3, 9, trailer)
    x = JuLS.CPVariable[x1, x2, x3]

    y = JuLS.IntVariable(1, 5, trailer)

    I = JuLS.Interval(2, 4)

    constraint = JuLS.Among(x, y, I, trailer)

    @test constraint.overlap_indexes.values == [1, 2, 3]
    @test constraint.set.inf == 2
    @test constraint.set.sup == 4

    @test constraint.low.value == 0
    @test constraint.up.value == 3
    @test JuLS.is_active(constraint)
end

@testitem "Among(::Singleton)" begin
    trailer = JuLS.Trailer()

    x1 = JuLS.IntVariable(1, 3, trailer)
    x2 = JuLS.IntVariable(2, 7, trailer)
    x3 = JuLS.IntVariable(3, 9, trailer)
    x = JuLS.CPVariable[x1, x2, x3]

    y = JuLS.IntVariable(1, 5, trailer)

    I = JuLS.Singleton(3)

    constraint = JuLS.Among(x, y, I, trailer)

    @test constraint.overlap_indexes.values == [1, 2, 3]
    @test constraint.set.value == 3

    @test constraint.low.value == 0
    @test constraint.up.value == 3
    @test JuLS.is_active(constraint)
end

@testitem "propagate!(::Among) with Interval" begin
    trailer = JuLS.Trailer()

    x1 = JuLS.IntVariable(1, 3, trailer)
    x2 = JuLS.IntVariable(2, 7, trailer)
    x3 = JuLS.IntVariable(3, 9, trailer)
    x = JuLS.CPVariable[x1, x2, x3]

    I = JuLS.Interval(2, 4)
    to_propagate = Set{JuLS.CPConstraint}()

    y1 = JuLS.IntVariable(0, 0, trailer)
    constraint = JuLS.Among(x, y1, I, trailer)
    JuLS.propagate!(constraint, to_propagate)

    @test 1 in x[1].domain
    @test !(2 in x[1].domain) && !(3 in x[1].domain)
    @test 5 in x[2].domain && !(2 in x[2].domain)

    x1 = JuLS.IntVariable(2, 3, trailer)
    x2 = JuLS.IntVariable(3, 4, trailer)
    x3 = JuLS.IntVariable(3, 9, trailer)
    x = JuLS.CPVariable[x1, x2, x3]

    y2 = JuLS.IntVariable(1, 5, trailer)

    constraint = JuLS.Among(x, y2, I, trailer)
    JuLS.propagate!(constraint, to_propagate)
    @test JuLS.minimum(y2.domain) == 2 && maximum(y2.domain) == 3
    @test JuLS.is_active(constraint)
end

@testitem "propagate!(::Among) with Singleton" begin
    trailer = JuLS.Trailer()

    x1 = JuLS.IntVariable(1, 3, trailer)
    x2 = JuLS.IntVariable(2, 7, trailer)
    x3 = JuLS.IntVariable(3, 9, trailer)

    x = JuLS.CPVariable[x1, x2, x3]

    I = JuLS.Singleton(3)
    y1 = JuLS.IntVariable(0, 0, trailer)

    constraint = JuLS.Among(x, y1, I, trailer)
    to_propagate = Set{JuLS.CPConstraint}()

    JuLS.propagate!(constraint, to_propagate)

    @test 1 in x[1].domain && (2 in x[1].domain) && !(3 in x[1].domain)
    @test 5 in x[2].domain && !(3 in x[2].domain)
    @test 8 in x[3].domain && !(3 in x[3].domain)
    @test !JuLS.is_active(constraint)

    x1 = JuLS.IntVariable(3, 3, trailer)
    x2 = JuLS.IntVariable(3, 3, trailer)
    x3 = JuLS.IntVariable(3, 9, trailer)
    x = JuLS.CPVariable[x1, x2, x3]

    y2 = JuLS.IntVariable(1, 5, trailer)

    constraint = JuLS.Among(x, y2, I, trailer)
    JuLS.propagate!(constraint, to_propagate)
    @test JuLS.minimum(y2.domain) == 2 && maximum(y2.domain) == 3
    @test JuLS.is_active(constraint)
end


function Base.show(io::IO, constraint::Among)
    print(
        io,
        string(typeof(constraint)),
        ": (",
        join([id(var) for var in constraint.x], ", "),
        ") ∈ ",
        constraint.set,
        " ≤ ",
        constraint.cap,
        ", active = ",
        is_active(constraint),
    )
end

function Base.show(io::IO, ::MIME"text/plain", constraint::Among)
    print(
        io,
        string(typeof(constraint)),
        ": (",
        join([id(var) for var in constraint.x], ", "),
        ") ∈ ",
        constraint.set,
        " ≤ ",
        constraint.cap,
        ", active = ",
        is_active(constraint),
    )
end
