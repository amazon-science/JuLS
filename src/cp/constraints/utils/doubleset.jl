# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import ..DoubleSet

function is_including(ds::DoubleSet{Int}, dom::Domain)
    is_including(ds.first_set, dom) || is_including(ds.second_set, dom)
end

function is_overlapping(ds::DoubleSet{Int}, dom::Domain)
    is_overlapping(ds.first_set, dom) || is_overlapping(ds.second_set, dom)
end

function is_intersecting(ds::DoubleSet{Int}, dom::Domain)
    is_intersecting(ds.first_set, dom) || is_intersecting(ds.second_set, dom)
end

Base.in(value::Int, ds::DoubleSet{Int}) = value in ds.first_set || value in ds.second_set

function remove!(dom::Domain, ds::DoubleSet{Int})
    remove!(dom, ds.first_set) && remove!(dom, ds.second_set)
end

Base.min(singleton::Singleton{Int}) = singleton.value
Base.max(singleton::Singleton{Int}) = singleton.value

Base.min(interval::Interval{Int}) = interval.inf
Base.max(interval::Interval{Int}) = interval.sup

function remove_all_but!(dom::Domain, ds::DoubleSet{Int})

    m = min(min(ds.first_set), min(ds.second_set))
    M = max(max(ds.second_set), max(ds.second_set))

    pruned_min = remove_below!(dom, m)
    pruned_between = false
    pruned_max = remove_above!(dom, M)

    if min(ds.first_set) > max(ds.second_set)
        pruned_between = remove_between!(dom, max(ds.second_set), min(ds.first_set))
    end

    if min(ds.second_set) > max(ds.first_set)
        pruned_between = remove_between!(dom, max(ds.first_set), min(ds.second_set))
    end

    return pruned_min || pruned_max || pruned_between
end

function Base.show(io::IO, ds::DoubleSet{Int})
    print(io, "{")
    print(io, ds.first_set)
    print(io, ", ")
    print(io, ds.second_set)
    print(io, "}")
end

function Base.show(io::IO, ::MIME"text/plain", ds::DoubleSet{Int})
    print(io, "{")
    print(io, ds.first_set)
    print(io, ", ")
    print(io, ds.second_set)
    print(io, "}")
end

@testitem "DoubleSet domain operations for Double Intervals" begin

    I_1 = JuLS.Interval(2, 4)
    I_2 = JuLS.Interval(6, 7)
    DS = JuLS.DoubleSet(I_1, I_2)
    trailer = JuLS.Trailer()

    dom_1 = JuLS.IntDomain(trailer, [2, 3])
    dom_2 = JuLS.IntDomain(trailer, [5, 7])
    @test JuLS.is_including(DS, dom_1)
    @test !JuLS.is_including(DS, dom_2)

    dom_1 = JuLS.IntDomain(trailer, [1, 5])
    dom_2 = JuLS.IntDomain(trailer, [8])
    @test JuLS.is_overlapping(DS, dom_1)
    @test !JuLS.is_overlapping(DS, dom_2)

    dom_1 = JuLS.IntDomain(trailer, [1, 4])
    dom_2 = JuLS.IntDomain(trailer, [1, 5])
    @test JuLS.is_intersecting(DS, dom_1)
    @test !JuLS.is_intersecting(DS, dom_2)

end

@testitem "remove!(::Domain,::DoubleSet) and remove_all_but!(::Domain,::DoubleSet) for Double Intervals" begin

    I_1 = JuLS.Interval(4, 6)
    I_2 = JuLS.Interval(5, 7)
    DS = JuLS.DoubleSet(I_1, I_2)
    trailer = JuLS.Trailer()
    dom = JuLS.IntDomain(trailer, [3, 4, 5, 7])
    JuLS.remove!(dom, DS)
    @test dom.size.value == 1
    @test 3 in dom

    I_1 = JuLS.Interval(4, 6)
    I_2 = JuLS.Interval(3, 5)
    DS = JuLS.DoubleSet(I_1, I_2)
    dom = JuLS.IntDomain(trailer, [3, 4, 5, 7])
    JuLS.remove_all_but!(dom, DS)
    @test dom.size.value == 3
    @test !(7 in dom)

end

@testitem "DoubleSet domain operations for Double Singletons" begin

    S_1 = JuLS.Singleton(3)
    S_2 = JuLS.Singleton(5)
    DS = JuLS.DoubleSet(S_1, S_2)
    trailer = JuLS.Trailer()

    dom_1 = JuLS.IntDomain(trailer, [3])
    dom_2 = JuLS.IntDomain(trailer, [4])
    @test JuLS.is_including(DS, dom_1)
    @test !JuLS.is_including(DS, dom_2)

    dom_1 = JuLS.IntDomain(trailer, [1, 3])
    dom_2 = JuLS.IntDomain(trailer, [1, 4])
    @test JuLS.is_overlapping(DS, dom_1)
    @test !JuLS.is_overlapping(DS, dom_2)

    dom_1 = JuLS.IntDomain(trailer, [1, 3])
    dom_2 = JuLS.IntDomain(trailer, [1, 4])
    @test JuLS.is_intersecting(DS, dom_1)
    @test !JuLS.is_intersecting(DS, dom_2)

end


@testitem "remove!(::Domain,::DoubleSet) and remove_all_but!(::Domain,::DoubleSet) for Double Singletons" begin

    S_1 = JuLS.Singleton(4)
    S_2 = JuLS.Singleton(7)
    DS = JuLS.DoubleSet(S_1, S_2)
    trailer = JuLS.Trailer()
    dom = JuLS.IntDomain(trailer, [3, 4, 7])
    JuLS.remove!(dom, DS)
    @test dom.size.value == 1
    @test 3 in dom

    S_1 = JuLS.Singleton(4)
    S_2 = JuLS.Singleton(5)
    DS = JuLS.DoubleSet(S_1, S_2)
    dom = JuLS.IntDomain(trailer, [3, 4, 7])
    JuLS.remove_all_but!(dom, DS)
    @test dom.size.value == 1
    @test 4 in dom

end

