# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct AmongUp <: CPConstraint

CPConstraint |{x | D(x) ⊂ I}| ≤ C
"""
struct AmongUp <: CPConstraint
    x::Vector{CPVariable}
    set::AbstractSet
    cap::Int

    overlap_indexes::IntDomain
    low::StateObject{Int}
    active::StateObject{Bool}
end

function AmongUp(x::Vector{CPVariable}, set::AbstractSet, cap::Int, trailer::Trailer)
    overlap_indexes = IntDomain(trailer, length(x), 0)
    low = StateObject{Int}(0, trailer)
    active = StateObject{Bool}(true, trailer)
    constraint = AmongUp(x, set, cap, overlap_indexes, low, active)
    add_on_domain_change!(constraint)
    return constraint
end

function propagate!(constraint::AmongUp, to_propagate::Set{CPConstraint})
    non_overlapping = Int[]
    low = constraint.low.value
    for i in constraint.overlap_indexes
        var = constraint.x[i]
        if is_including(constraint.set, var.domain)
            low += 1
            push!(non_overlapping, i)
            continue
        end
        if !is_overlapping(constraint.set, var.domain)
            push!(non_overlapping, i)
        end
    end
    set_value!(constraint.low, low)
    remove!(constraint.overlap_indexes, non_overlapping)
    if low == constraint.cap
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
    if isempty(constraint.overlap_indexes) || length(constraint.overlap_indexes) <= (constraint.cap - low)
        set_value!(constraint.active, false)
    end
    return low <= constraint.cap
end

variables(constraint::AmongUp) = constraint.x

@testitem "AmongUp(::Interval)" begin
    trailer = JuLS.Trailer()

    x1 = JuLS.IntVariable(1, 3, trailer)
    x2 = JuLS.IntVariable(2, 7, trailer)
    x3 = JuLS.IntVariable(3, 9, trailer)

    x = JuLS.CPVariable[x1, x2, x3]

    I = JuLS.Interval(2, 4)
    cap = 0

    constraint = JuLS.AmongUp(x, I, cap, trailer)

    @test constraint.cap == 0
    @test constraint.overlap_indexes.values == [1, 2, 3]
    @test constraint.set.inf == 2
    @test constraint.set.sup == 4

    @test constraint.low.value == 0
    @test JuLS.is_active(constraint)
end

@testitem "AmongUp(::Singleton)" begin
    trailer = JuLS.Trailer()

    x1 = JuLS.IntVariable(1, 3, trailer)
    x2 = JuLS.IntVariable(2, 7, trailer)
    x3 = JuLS.IntVariable(3, 9, trailer)

    x = JuLS.CPVariable[x1, x2, x3]

    I = JuLS.Singleton(3)
    cap = 0

    constraint = JuLS.AmongUp(x, I, cap, trailer)

    @test constraint.cap == 0
    @test constraint.overlap_indexes.values == [1, 2, 3]
    @test constraint.set.value == 3

    @test constraint.low.value == 0
    @test JuLS.is_active(constraint)
end

@testitem "propagate!(::AmongUp) with Interval" begin
    trailer = JuLS.Trailer()

    x1 = JuLS.IntVariable(1, 3, trailer)
    x2 = JuLS.IntVariable(2, 7, trailer)
    x3 = JuLS.IntVariable(3, 9, trailer)

    x = JuLS.CPVariable[x1, x2, x3]

    I = JuLS.Interval(2, 4)
    cap = 0

    constraint = JuLS.AmongUp(x, I, cap, trailer)
    to_propagate = Set{JuLS.CPConstraint}()

    JuLS.propagate!(constraint, to_propagate)

    @test 1 in x[1].domain
    @test !(2 in x[1].domain) && !(3 in x[1].domain)
    @test 5 in x[2].domain && !(2 in x[2].domain)
end

@testitem "propagate!(::AmongUp) with Singleton" begin
    trailer = JuLS.Trailer()

    x1 = JuLS.IntVariable(1, 3, trailer)
    x2 = JuLS.IntVariable(2, 7, trailer)
    x3 = JuLS.IntVariable(3, 9, trailer)

    x = JuLS.CPVariable[x1, x2, x3]

    I = JuLS.Singleton(3)
    cap = 0

    constraint = JuLS.AmongUp(x, I, cap, trailer)
    to_propagate = Set{JuLS.CPConstraint}()

    JuLS.propagate!(constraint, to_propagate)

    @test 1 in x[1].domain && (2 in x[1].domain) && !(3 in x[1].domain)
    @test 5 in x[2].domain && !(3 in x[2].domain)
    @test 8 in x[3].domain && !(3 in x[3].domain)
    @test !JuLS.is_active(constraint)
end


function Base.show(io::IO, constraint::AmongUp)
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

function Base.show(io::IO, ::MIME"text/plain", constraint::AmongUp)
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
