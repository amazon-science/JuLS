# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct IntDomain <: Domain

Sparse integer domain. Can contain any set of integer.

You must note that this implementation takes as much space as the size of the initial domain.
However, it can be pretty efficient in accessing and editing. Operation costs are detailed for each method.
"""
struct IntDomain <: Domain
    values::Array{Int}
    indexes::Array{Int}
    offset::Int
    size::StateObject{Int}
    min::StateObject{Int}
    max::StateObject{Int}
    trailer::Trailer
end

"""
    IntDomain(trailer::Trailer, n::Int, offset::Int)

Create an integer domain going from `ofs + 1` to `ofs + n`.
Will be backtracked by the given `trailer`.
"""
function IntDomain(trailer::Trailer, n::Int, offset::Int)

    size = StateObject{Int}(n, trailer)
    min = StateObject{Int}(offset + 1, trailer)
    max = StateObject{Int}(offset + n, trailer)
    values = zeros(n)
    indexes = zeros(n)
    for i = 1:n
        values[i] = i
        indexes[i] = i
    end
    return IntDomain(values, indexes, offset, size, min, max, trailer)
end

function IntDomain(trailer::Trailer, values::Vector{Int})
    @assert length(unique(values)) == length(values)

    values = sort(values)
    size = StateObject{Int}(length(values), trailer)
    min = StateObject{Int}(values[1], trailer)
    max = StateObject{Int}(values[end], trailer)
    offset = min.value - 1
    values .-= offset
    interval_size = max.value - min.value + 1
    indexes = zeros(Int, interval_size)
    for (i, v) in enumerate(values)
        indexes[v] = i
    end
    return IntDomain(values, indexes, offset, size, min, max, trailer)
end

"""
    reset_domain!(dom::IntDomain)

Used in `reset_run!`. 
"""
function reset_domain!(dom::IntDomain)
    set_value!(dom.size, length(dom.values))
    set_value!(dom.min, dom.offset + 1)
    set_value!(dom.max, dom.offset + length(dom.indexes))
    sort!(dom.values)
    for (i, v) in enumerate(dom.values)
        dom.indexes[v] = i
    end
    dom
end

function Base.show(io::IO, dom::IntDomain)
    print(io, "[", join(dom, " "), "]")
end

function Base.show(io::IO, ::MIME"text/plain", dom::IntDomain)
    print(io, typeof(dom), ": [", join(dom, " "), "]")
end

"""
    isempty(dom::IntDomain)

Return `true` iff `dom` is an empty set. Done in constant time.
"""
Base.isempty(dom::IntDomain) = dom.size.value == 0

isbound(dom::IntDomain) = dom.size.value == 1

"""
    length(dom::IntDomain)

Return the size of `dom`. Done in constant time.
"""
Base.length(dom::IntDomain) = dom.size.value

"""
    Base.in(value::Int, dom::IntDomain)

Check if an integer is in the domain. Done in constant time.
"""
function Base.in(value::Int, dom::IntDomain)
    value -= dom.offset
    if value < 1 || value > length(dom.indexes)
        return false
    end
    return 0 < dom.indexes[value] <= length(dom)
end


"""
    remove!(dom::IntDomain, value::Int)

Remove `value` from `dom`. Done in constant time.
"""
function remove!(dom::IntDomain, value::Int)
    if value in dom
        value -= dom.offset

        exchange_positions!(dom, value, dom.values[dom.size.value])
        set_value!(dom.size, dom.size.value - 1)

        update_bounds!(dom, value + dom.offset)

        return true
    end
    return false
end

"""
    remove!(dom::IntDomain, value::Int)

Remove a value vector `values` from `dom`. Done in constant time.
"""
function remove!(dom::IntDomain, values::Vector{Int})
    return any(remove!.(Ref(dom), values))
end

"""
    remove_all_but!(dom::IntDomain, value::Int)

Remove all values from `dom` except `value`. Done in constant time.
"""
function remove_all_but!(dom::IntDomain, value::Int)
    if !(value in dom)
        pruned = dom.size.value > 0
        set_value!(dom.size, 0)
        return pruned
    end

    pruned = dom.size.value > 1
    value -= dom.offset

    exchange_positions!(dom, value, dom.values[1])

    set_value!(dom.size, 1)
    set_value!(dom.max, value + dom.offset)
    set_value!(dom.min, value + dom.offset)

    return pruned
end


"""
    remove_all!(dom::IntDomain)

Remove every value from `dom`. Return false. Done in constant time.
"""
function remove_all!(dom::IntDomain)
    pruned = dom.size.value > 0
    set_value!(dom.size, 0)
    return pruned
end

"""
    remove_above!(dom::IntDomain, value::Int)

Remove every integer of `dom` that is *strictly* above `value`. Done in *linear* time.
"""
function remove_above!(dom::IntDomain, value::Int)
    if dom.min.value > value
        return remove_all!(dom)
    end

    pruned = false
    for i = (value+1):dom.max.value
        if i in dom
            pruned = true
            remove!(dom, i)
        end
    end
    return pruned
end

"""
    remove_below!(dom::IntDomain, value::Int)

Remove every integer of `dom` that is *strictly* below `value`. 
Done in *linear* time.
"""
function remove_below!(dom::IntDomain, value::Int)
    if dom.max.value < value
        return remove_all!(dom)
    end

    pruned = false
    for i = (value-1):-1:dom.min.value
        if i in dom
            pruned = true
            remove!(dom, i)
        end
    end
    return pruned
end

"""
    remove_between!(dom::IntDomain, min::Int, max::Int)

Remove every integer of `dom` that is  *strictly* between `min` and `max`.
"""
function remove_between!(dom::IntDomain, min::Int, max::Int)
    if dom.max.value < max && dom.min.value > min
        return remove_all!(dom)
    end

    min = Base.max(min + 1, dom.min.value)
    max = Base.min(max - 1, dom.max.value)

    pruned = false
    for i = min:max
        if i in dom
            pruned = true
            remove!(dom, i)
        end
    end
    return pruned
end

"""
    assign!(dom::IntDomain, value::Int)

Remove everything from the domain but `value`.
Done in *constant* time.
"""
function assign!(dom::IntDomain, value::Int)
    @assert value in dom

    value -= dom.offset

    exchange_positions!(dom, value, dom.values[1])

    set_value!(dom.size, 1)
    set_value!(dom.max, value + dom.offset)
    set_value!(dom.min, value + dom.offset)
end


"""
    Base.iterate(dom::IntDomain, state=1)

Iterate over the domain in an efficient way. The order may not be consistent.
WARNING: Do **NOT** update the domain you are iterating on.
"""
function Base.iterate(dom::IntDomain, state = 1)
    @assert state >= 1
    if state > dom.size.value
        return nothing
    end

    return dom.values[state] + dom.offset, state + 1
end

"""
    exchange_positions!(dom::IntDomain, v1::Int, v2::Int)

Intended for internal use only, exchange the position of `v1` and `v2` in the array of the domain.
"""
function exchange_positions!(dom::IntDomain, v1::Int, v2::Int)

    @assert(v1 <= length(dom.indexes) && v2 <= length(dom.indexes))

    i1, i2 = dom.indexes[v1], dom.indexes[v2]

    dom.values[i1] = v2
    dom.values[i2] = v1
    dom.indexes[v1] = i2
    dom.indexes[v2] = i1

    return dom
end

"""
    update_max!(dom::IntDomain, v::Int)

Knowing that `v` just got removed from `dom`, update `dom`'s maximum value.
Done in *constant* time.
"""
function update_max!(dom::IntDomain, v::Int)
    if !isempty(dom) && maximum(dom) == v
        @assert !(v in dom)
        currentVal = v - 1
        while currentVal >= minimum(dom)
            if currentVal in dom
                break
            end
            currentVal -= 1
        end
        set_value!(dom.max, currentVal)
    end
end

"""
    update_min!(dom::IntDomain, v::Int)

Knowing that `v` just got removed from `dom`, update `dom`'s minimum value.
Done in *constant* time.
"""
function update_min!(dom::IntDomain, v::Int)
    if !isempty(dom) && minimum(dom) == v
        @assert !(v in dom)
        currentVal = v + 1
        while currentVal <= maximum(dom)
            if currentVal in dom
                break
            end
            currentVal += 1
        end
        set_value!(dom.min, currentVal)
    end
end

"""
    update_bounds!(dom::Domain, v::Int)

Knowing that `v` just got removed from `dom`, update `dom`'s minimum and maximum value.
Done in *constant* time.
"""
function update_bounds!(dom::Domain, v::Int)
    update_max!(dom, v)
    update_min!(dom, v)
end

"""
    minimum(dom::IntDomain)

Return the minimum value of `dom`.
Done in *constant* time.
"""
Base.minimum(dom::IntDomain) = dom.min.value

"""
    maximum(dom::IntDomain)

Return the maximum value of `dom`.
Done in *constant* time.
"""
Base.maximum(dom::IntDomain) = dom.max.value


@testitem "isempty()" begin
    trailer = JuLS.Trailer()
    domNotEmpty = JuLS.IntDomain(trailer, 20, 10)

    @test !isempty(domNotEmpty)

    emptyDom = JuLS.IntDomain(trailer, 0, 1)
    @test isempty(emptyDom)
end

@testitem "length()" begin
    trailer = JuLS.Trailer()
    dom20 = JuLS.IntDomain(trailer, 20, 10)
    @test length(dom20) == 20

    dom2 = JuLS.IntDomain(trailer, 2, 0)

    @test length(dom2) == 2
end

@testitem "in()" begin
    trailer = JuLS.Trailer()
    dom20 = JuLS.IntDomain(trailer, 20, 10)

    @test 11 in dom20
    @test !(10 in dom20)
    @test 21 in dom20
    @test !(1 in dom20)
    @test !(31 in dom20)
end

@testitem "exchange_positions!()" begin
    trailer = JuLS.Trailer()
    dom = JuLS.IntDomain(trailer, 5, 10)

    @test dom.values == [1, 2, 3, 4, 5]
    @test dom.indexes == [1, 2, 3, 4, 5]

    JuLS.exchange_positions!(dom, 2, 5)

    @test dom.values == [1, 5, 3, 4, 2]
    @test dom.indexes == [1, 5, 3, 4, 2]

    JuLS.exchange_positions!(dom, 2, 1)

    @test dom.values == [2, 5, 3, 4, 1]
    @test dom.indexes == [5, 1, 3, 4, 2]
end

@testitem "remove!()" begin
    trailer = JuLS.Trailer()
    dom = JuLS.IntDomain(trailer, 5, 10)

    JuLS.remove!(dom, 11)

    @test !(11 in dom)
    @test length(dom) == 4
    @test dom.min.value == 12
end

@testitem "assign!()" begin
    trailer = JuLS.Trailer()
    dom = JuLS.IntDomain(trailer, 5, 10)

    JuLS.assign!(dom, 14)

    @test !(12 in dom)
    @test 14 in dom
    @test length(dom) == 1
    @test dom.max.value == 14 && dom.min.value == 14
end

@testitem "iterate()" begin
    trailer = JuLS.Trailer()
    dom = JuLS.IntDomain(trailer, 8, 2)

    JuLS.remove!(dom, 6)

    values = [i for i in dom]

    @test values == [3, 4, 5, 10, 7, 8, 9]
end

@testitem "remove_all!()" begin
    trailer = JuLS.Trailer()
    dom = JuLS.IntDomain(trailer, 3, 10)

    JuLS.remove_all!(dom)

    @test isempty(dom)
end

@testitem "remove_between!()" begin
    trailer = JuLS.Trailer()
    dom = JuLS.IntDomain(trailer, 5, 10)

    JuLS.remove_between!(dom, 11, 14)

    @test 11 in dom
    @test !(12 in dom)
    @test !(13 in dom)
    @test 14 in dom
end

@testitem "update_min!()" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(5, 10, trailer)

    @test minimum(x.domain) == 5

    JuLS.remove!(x.domain, 5)
    JuLS.update_min!(x.domain, 5)

    @test minimum(x.domain) == 6
end

@testitem "update_max!()" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(5, 10, trailer)

    @test maximum(x.domain) == 10

    JuLS.remove!(x.domain, 10)
    JuLS.update_max!(x.domain, 10)

    @test maximum(x.domain) == 9
end

@testitem "update_bounds!()" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(5, 10, trailer)

    JuLS.remove!(x.domain, 5)
    JuLS.remove!(x.domain, 10)
    JuLS.update_bounds!(x.domain, 5)
    JuLS.update_bounds!(x.domain, 10)

    @test minimum(x.domain) == 6
    @test maximum(x.domain) == 9
end

@testitem "remove_above!()" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(5, 10, trailer)

    @test JuLS.remove_above!(x.domain, 7)

    @test length(x.domain) == 3
    @test 7 in x.domain
    @test 6 in x.domain
    @test !(8 in x.domain)
    @test !(9 in x.domain)

    @test JuLS.remove_above!(x.domain, 4)

    @test isempty(x.domain)
end

@testitem "remove_below!()" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(5, 10, trailer)

    @test JuLS.remove_below!(x.domain, 7)

    @test length(x.domain) == 4
    @test 7 in x.domain
    @test 8 in x.domain
    @test !(6 in x.domain)
    @test !(5 in x.domain)

    @test JuLS.remove_below!(x.domain, 11)

    @test isempty(x.domain)
end

@testitem "minimum()" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(5, 10, trailer)

    @test JuLS.minimum(x.domain) == 5
end


@testitem "maximum()" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(5, 10, trailer)

    @test JuLS.maximum(x.domain) == 10
end

@testitem "reset_domain!()" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(5, 10, trailer)
    JuLS.assign!(x, 10)

    @test x.domain.values == [6, 2, 3, 4, 5, 1]
    @test x.domain.indexes == [6, 2, 3, 4, 5, 1]
    @test JuLS.length(x.domain) == 1
    JuLS.reset_domain!(x.domain)
    @test x.domain.values == [1, 2, 3, 4, 5, 6]
    @test x.domain.indexes == [1, 2, 3, 4, 5, 6]
    @test JuLS.length(x.domain) == 6
end