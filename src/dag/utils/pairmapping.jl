# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    PairMapping{T}

A mutable structure for managing two key-value pairs with integer keys and values of type T.

# Fields
- `key1::Int`: First key
- `value1::T`: First value
- `key2::Int`: Second key
- `value2::T`: Second value

# Constructors
    PairMapping{T}(key1::Int, key2::Int)    # With specific keys
    PairMapping{T}()                        # Default keys (1,2)
"""
mutable struct PairMapping{T}
    key1::Int
    value1::T
    key2::Int
    value2::T

    PairMapping{T}(key1::Int, key2::Int) where {T} = new(key1, Base.zero(T), key2, Base.zero(T))
end
PairMapping{T}() where {T} = PairMapping{T}(1, 2)

function Base.setindex!(m::PairMapping{T}, value::T, key::Int) where {T}
    if m.key1 == key
        m.value1 = value
    elseif m.key2 == key
        m.value2 = value
    else
        throw(KeyError(key))
    end
    return m
end

function Base.getindex(m::PairMapping, key::Int)
    if m.key1 == key
        return m.value1
    elseif m.key2 == key
        return m.value2
    end
    throw(KeyError(key))
end

setkeys!(m::PairMapping, key1::Int, key2::Int) = m.key1, m.key2 = key1, key2

Base.length(::PairMapping) = 2
Base.isempty(::PairMapping) = false
Base.keys(m::PairMapping) = [m.key1, m.key2]
Base.values(m::PairMapping) = [m.value1, m.value2]

first_key(m::PairMapping) = m.key1
second_key(m::PairMapping) = m.key2
first_value(m::PairMapping) = m.value1
second_value(m::PairMapping) = m.value2

@testitem "setindex!(::PairMapping)" begin
    m = JuLS.PairMapping{Int}(34, 21)
    m[34] = 97
    @test m[34] == 97
    m[34] = 7
    @test m[34] == 7
    m[21] = 13
    @test m[21] == 13
    @test_throws KeyError m[56] = 8
end

@testitem "getindex(::PairMapping)" begin
    m = JuLS.PairMapping{Int}(34, 21)
    m[34] = 7
    m[21] = 13
    @test m[34] == 7
    @test m[21] == 13
    @test_throws KeyError m[98]
end

@testitem "setkeys!(::PairMapping)" begin
    m = JuLS.PairMapping{Int}(34, 21)
    m[34] = 7
    m[21] = 13
    JuLS.setkeys!(m, 76, 89)
    @test m.key1 == 76
    @test m.key2 == 89
    @test m[76] == 7
    @test m[89] == 13
end