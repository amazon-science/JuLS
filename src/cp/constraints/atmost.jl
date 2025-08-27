# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct Among <: CPConstraint

CPConstraint |{x | x = v}| ≤ C
"""
struct AtMost <: CPConstraint
    variables::Vector{CPVariable}
    capped_value::Int
    cap::Int

    overlap_set::IntDomain
    count::StateObject{Int}
    active::StateObject{Bool}
end

function AtMost(variables::Vector{CPVariable}, capped_value::Int, cap::Int, trailer::Trailer)
    useful_variables = CPVariable[]
    count_value = 0
    for var in variables
        if isbound(var) && assigned_value(var) == capped_value
            count_value += 1
        elseif capped_value in var.domain
            push!(useful_variables, var)
        end
    end

    overlap_set = IntDomain(trailer, length(useful_variables), 0)
    count = StateObject{Int}(count_value, trailer)
    active = StateObject{Bool}(true, trailer)

    constraint = AtMost(useful_variables, capped_value, cap, overlap_set, count, active)

    add_on_domain_change!(constraint)

    return constraint
end

function propagate!(constraint::AtMost, to_propagate::Set{CPConstraint})
    non_overlapping = Int[]
    for i in constraint.overlap_set
        var = constraint.variables[i]
        if isbound(var) && assigned_value(var) == constraint.capped_value
            set_value!(constraint.count, constraint.count.value + 1)
            push!(non_overlapping, i)
        end

        if !(constraint.capped_value in var.domain)
            push!(non_overlapping, i)
        end
    end

    remove!(constraint.overlap_set, non_overlapping)

    if constraint.count.value == constraint.cap
        set_value!(constraint.active, false)
        for i in constraint.overlap_set
            var = constraint.variables[i]

            if remove!(var.domain, constraint.capped_value)
                trigger_domain_change!(to_propagate, var)
            end

            if isempty(var.domain)
                return false
            end
        end
        return true
    end

    if isempty(constraint.overlap_set) || length(constraint.overlap_set) <= (constraint.cap - constraint.count.value)
        set_value!(constraint.active, false)
    end

    return constraint.count.value <= constraint.cap
end

variables(constraint::AtMost) = constraint.variables

@testitem "AtMost()" begin
    trailer = JuLS.Trailer()

    x1 = JuLS.IntVariable(1, 3, trailer)
    x2 = JuLS.IntVariable(2, 7, trailer)
    x3 = JuLS.IntVariable(3, 9, trailer)

    x = JuLS.CPVariable[x1, x2, x3]

    v = 3
    cap = 0

    constraint = JuLS.AtMost(x, v, cap, trailer)

    @test constraint.cap == 0
    @test constraint.overlap_set.values == [1, 2, 3]
    @test constraint.capped_value == 3

    @test constraint.count.value == 0
    @test JuLS.is_active(constraint)
end

@testitem "propagate!(::AtMost)" begin
    trailer = JuLS.Trailer()

    x1 = JuLS.IntVariable(1, 3, trailer)
    x2 = JuLS.IntVariable(2, 7, trailer)
    x3 = JuLS.IntVariable(3, 9, trailer)

    x = JuLS.CPVariable[x1, x2, x3]

    v = 3
    cap = 0

    constraint = JuLS.AtMost(x, v, cap, trailer)
    to_propagate = Set{JuLS.CPConstraint}()

    JuLS.propagate!(constraint, to_propagate)

    @test 1 in x[1].domain && (2 in x[1].domain) && !(3 in x[1].domain)
    @test 5 in x[2].domain && !(3 in x[2].domain)
    @test 8 in x[3].domain && !(3 in x[3].domain)
    @test !JuLS.is_active(constraint)
end


function Base.show(io::IO, constraint::AtMost)
    print(
        io,
        string(typeof(constraint)),
        ": (",
        join([id(var) for var in constraint.variables], ", "),
        ") = ",
        constraint.capped_value,
        " ≤ ",
        constraint.cap,
        ", active = ",
        is_active(constraint),
    )
end

function Base.show(io::IO, ::MIME"text/plain", constraint::AtMost)
    print(
        io,
        string(typeof(constraint)),
        ": (",
        join([id(var) for var in constraint.variables], ", "),
        ") = ",
        constraint.capped_value,
        " ≤ ",
        constraint.cap,
        ", active = ",
        is_active(constraint),
    )
end