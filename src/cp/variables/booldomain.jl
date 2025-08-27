# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

abstract type AbstractBoolDomain <: Domain end

"""
    struct BoolDomain <: Domain

Boolean domain, uses a IntDomain in it. (true is 1 and false is 0)
"""
struct BoolDomain <: AbstractBoolDomain
    inner::IntDomain

    function BoolDomain(trailer::Trailer)
        return new(IntDomain(trailer, 2, -1))
    end
end

"""
    reset_domain!(dom::BoolDomain)

Used in `reset_run!`. 
"""
reset_domain!(dom::BoolDomain) = reset_domain!(dom.inner)

function Base.show(io::IO, dom::BoolDomain)
    print(io, "[", join(dom, " "), "]")
end

function Base.show(io::IO, ::MIME"text/plain", dom::BoolDomain)
    print(io, typeof(dom), ": [", join(dom, " "), "]")
end

"""
    isempty(dom::BoolDomain)

Return `true` iff `dom` is an empty set. Done in constant time.
"""
Base.isempty(dom::BoolDomain) = Base.isempty(dom.inner)

"""
    length(dom::BoolDomain)

Return the size of `dom`. Done in constant time.
"""
Base.length(dom::BoolDomain) = Base.length(dom.inner)

isbound(dom::BoolDomain) = length(dom) == 1

"""
    Base.in(value::Int, dom::BoolDomain)

Check if an integer is in the domain. Done in constant time.
"""
function Base.in(value::Bool, dom::BoolDomain)
    intValue = convert(Int, value)
    return Base.in(intValue, dom.inner)
end

"""
    remove!(dom::BoolDomain, value::Bool)

Remove `value` from `dom`. Done in constant time.
"""
function remove!(dom::BoolDomain, value::Bool)
    if !(value in dom)
        return false
    end

    return remove!(dom.inner, convert(Int, value))
end

"""
    remove!(dom::BoolDomain, value::Int)

Remove `value` from `dom`. Done in constant time.
"""
remove!(dom::BoolDomain, value::Int) = remove!(dom.inner, value)

"""
    remove_above!(dom::BoolDomain, value::Int)

Remove every integer of `dom` that is *strictly* above `value`. Done in constant time.
"""
remove_above!(dom::BoolDomain, value::Int) = remove_above!(dom.inner, value)

"""
    remove_below!(dom::BoolDomain, value::Int)

Remove every integer of `dom` that is *strictly* below `value`. Done in constant time.
"""
remove_below!(dom::BoolDomain, value::Int) = remove_below!(dom.inner, value)

"""
    remove_between!(dom::BoolDomain, min::Int, max::Int)

Remove every integer of `dom` that is  *strictly* between `min` and `max`.
"""
remove_between!(dom::BoolDomain, min::Int, max::Int) = remove_between!(dom.inner, min, max)

"""
    remove_all!(dom::BoolDomain)

Remove every value from `dom`.
"""
remove_all!(dom::BoolDomain) = remove_all!(dom.inner)



"""
    assign!(dom::BoolDomain, value::Bool)

Remove everything from the domain but `value`.
Done in *constant* time.
"""
function assign!(dom::BoolDomain, value::Bool)
    @assert value in dom
    assign!(dom.inner, convert(Int, value))

    return true
end

"""
    assign!(dom::BoolDomain, value::Int)

Remove everything from the domain but `value`.
Done in *constant* time.
"""
assign!(dom::BoolDomain, value::Int) = assign!(dom.inner, convert(Int, value))

"""
    Base.iterate(dom::BoolDomain, state=1)

Iterate over the domain in an efficient way. The order may not be consistent.
WARNING: Do **NOT** update the domain you are iterating on.
"""
function Base.iterate(dom::BoolDomain, state = 1)
    returned = iterate(dom.inner, state)
    if isnothing(returned)
        return nothing
    end

    value, newState = returned
    return convert(Bool, value), newState
end

"""
    minimum(dom::BoolDomain)

Return the minimum value of `dom`.
Done in *constant* time.
"""
Base.minimum(dom::BoolDomain) = minimum(dom.inner)

"""
    maximum(dom::BoolDomain)

Return the maximum value of `dom`.
Done in *constant* time.
"""
Base.maximum(dom::BoolDomain) = maximum(dom.inner)


@testitem "isempty()" begin
    trailer = JuLS.Trailer()
    dom = JuLS.BoolDomain(trailer)

    @test !isempty(dom)

    JuLS.remove!(dom, false)
    JuLS.remove!(dom, true)
    @test isempty(dom)
end

@testitem "length()" begin
    trailer = JuLS.Trailer()
    dom = JuLS.BoolDomain(trailer)
    @test length(dom) == 2

    JuLS.remove!(dom, false)
    @test length(dom) == 1

    JuLS.remove!(dom, true)
    @test length(dom) == 0
end

@testitem "in()" begin
    trailer = JuLS.Trailer()
    dom = JuLS.BoolDomain(trailer)

    @test true in dom
    @test 1 in dom
    @test false in dom
    @test 0 in dom
    @test !(2 in dom)
    @test !(-1 in dom)
    JuLS.remove!(dom, false)
    @test !(false in dom)
    @test !(0 in dom)
end

@testitem "remove!(::Bool)" begin
    trailer = JuLS.Trailer()

    dom = JuLS.BoolDomain(trailer)
    JuLS.remove!(dom, false)
    @test !(false in dom)
    @test length(dom) == 1

    dom = JuLS.BoolDomain(trailer)
    JuLS.remove!(dom, true)
    @test !(true in dom)
    @test length(dom) == 1
    JuLS.remove!(dom, false)
    @test isempty(dom)
end

@testitem "remove!(::Int)" begin
    trailer = JuLS.Trailer()

    dom = JuLS.BoolDomain(trailer)
    JuLS.remove!(dom, 0)
    @test !(false in dom)
    @test length(dom) == 1

    dom = JuLS.BoolDomain(trailer)
    JuLS.remove!(dom, 1)
    @test !(true in dom)
    @test length(dom) == 1
    JuLS.remove!(dom, 0)
    @test isempty(dom)
end

@testitem "remove_above!()" begin
    trailer = JuLS.Trailer()

    dom = JuLS.BoolDomain(trailer)
    JuLS.remove_above!(dom, 0)
    @test false in dom
    @test length(dom) == 1

    dom = JuLS.BoolDomain(trailer)
    JuLS.remove_above!(dom, 1)
    @test length(dom) == 2
end

@testitem "remove_below!()" begin
    trailer = JuLS.Trailer()

    dom = JuLS.BoolDomain(trailer)
    JuLS.remove_below!(dom, 0)
    @test length(dom) == 2

    dom = JuLS.BoolDomain(trailer)
    JuLS.remove_below!(dom, 1)
    @test true in dom
    @test length(dom) == 1
end

@testitem "assign!(::Bool)" begin
    trailer = JuLS.Trailer()

    dom = JuLS.BoolDomain(trailer)
    JuLS.assign!(dom, true)
    @test !(false in dom)
    @test true in dom
    @test length(dom) == 1

    dom = JuLS.BoolDomain(trailer)
    JuLS.assign!(dom, false)
    @test !(true in dom)
    @test false in dom
    @test length(dom) == 1
end

@testitem "assign!(::Int)" begin
    trailer = JuLS.Trailer()

    dom = JuLS.BoolDomain(trailer)
    JuLS.assign!(dom, 1)
    @test !(false in dom)
    @test true in dom
    @test length(dom) == 1

    dom = JuLS.BoolDomain(trailer)
    JuLS.assign!(dom, 0)
    @test !(true in dom)
    @test false in dom
    @test length(dom) == 1
end

@testitem "iterate()" begin
    trailer = JuLS.Trailer()
    dom = JuLS.BoolDomain(trailer)

    values = [i for i in dom]
    @test values == [false, true]
end

@testitem "remove_all!()" begin
    trailer = JuLS.Trailer()
    dom = JuLS.BoolDomain(trailer)

    JuLS.remove_all!(dom)

    @test isempty(dom)
end

@testitem "minimum()" begin
    trailer = JuLS.Trailer()

    dom = JuLS.BoolDomain(trailer)
    @test JuLS.minimum(dom) == 0
    @test JuLS.minimum(dom) == false

    JuLS.remove!(dom, false)
    @test JuLS.minimum(dom) == 1
    @test JuLS.minimum(dom) == true
end

@testitem "maximum()" begin
    trailer = JuLS.Trailer()

    dom = JuLS.BoolDomain(trailer)
    @test JuLS.maximum(dom) == 1
    @test JuLS.maximum(dom) == true

    JuLS.remove!(dom, true)
    @test JuLS.maximum(dom) == 0
    @test JuLS.maximum(dom) == false
end
