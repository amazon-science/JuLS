# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    Interval{T} <: Base.AbstractSet{T}
    Singleton{T} <: Base.AbstractSet{T}
    DoubleSet{T} <: Base.AbstractSet{T}

Collection of set types for representing intervals, single values, and combinations of sets.
"""
struct Interval{T} <: Base.AbstractSet{T}
    inf::T
    sup::T
end

struct Singleton{T} <: Base.AbstractSet{T}
    value::T
end

struct DoubleSet{T} <: Base.AbstractSet{T}
    first_set::Base.AbstractSet{T}
    second_set::Base.AbstractSet{T}
end

function Base.in(value::T, interval::Interval{T}) where {T}
    return !isnothing(value) && value <= interval.sup && value >= interval.inf
end

function Base.in(value::T, singleton::Singleton{T}) where {T}
    return value == singleton.value
end

function Base.in(x::T, double_set::DoubleSet{T}) where {T}
    x in double_set.first_set || x in double_set.second_set
end


@testitem "in(::Singleton)" begin
    using Dates

    S = JuLS.Singleton(2)

    @test !(1 in S)
    @test 2 in S

    datetime = DateTime(2000, 1, 1)
    S = JuLS.Singleton(datetime)

    @test datetime in S
    @test !(datetime + Millisecond(1) in S)
end

@testitem "in(::Interval)" begin
    using Dates

    I = JuLS.Interval(3, 8)

    @test 4 in I
    @test 3 in I
    @test !(2 in I)

    inf = DateTime(2000, 1, 1)
    sup = DateTime(2000, 1, 2)
    I = JuLS.Interval{DateTime}(inf, sup)

    @test DateTime(2000, 1, 1, 20) in I
    @test inf in I
    @test sup in I
    @test !(inf - Millisecond(1) in I)
    @test !(sup + Day(1) in I)
end

@testitem "in(::DoubleSet)" begin
    using Dates

    inf_1 = DateTime(2000, 1, 1)
    sup_1 = DateTime(2000, 1, 2)
    I_1 = JuLS.Interval(inf_1, sup_1)

    inf_2 = DateTime(2003, 1, 1)
    sup_2 = DateTime(2003, 1, 2)
    I_2 = JuLS.Interval(inf_2, sup_2)

    M_interval = JuLS.DoubleSet(I_1, I_2)

    @test DateTime(2000, 1, 1, 20) in M_interval
    @test DateTime(2003, 1, 1, 20) in M_interval

    s_1 = JuLS.Singleton(DateTime(2000, 1, 2))
    s_2 = JuLS.Singleton(DateTime(2000, 1, 3))

    M_singleton = JuLS.DoubleSet(s_1, s_2)

    @test DateTime(2000, 1, 2) in M_singleton
    @test !(DateTime(2000, 1, 4) in M_singleton)
end