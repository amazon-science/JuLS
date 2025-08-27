# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

abstract type VariableView <: CPVariable end
abstract type DomainView <: Domain end
"""
    struct DomainViewOffset

Domain for an integer variable that is offset by a constant 'c' (y = x + c)
"""
struct DomainViewOffset <: DomainView
    inner::Domain
    c::Int
end
"""
    struct DomainViewMul
Domain for an integer variable that is a multiple of another integer variable.
"""
struct DomainViewMul <: DomainView
    inner::Domain
    c::Int
end
"""
    struct DomainViewOpposite
Domain for an integer variable that is the opposite of another integer variable (`y = -x`) 
"""
struct DomainViewOpposite <: DomainView
    inner::Domain
end


"""
    struct VarViewOffset <: VariableView

Create a *fake* variable `y`, such that `y = x + c`. This variable behaves like an usual one.
"""
mutable struct VarViewOffset <: VariableView
    id::Int
    x::CPVariable
    c::Int
    domain::DomainViewOffset
end
"""
    struct VarViewMul <: VariableView

Creates a *fake* variable `y`, such that `y = x * c`. This variable behaves like an usual one.
"""
struct VarViewMul <: VariableView
    id::Int
    x::CPVariable
    c::Int
    domain::DomainViewMul
end
"""
    struct VarViewOpposite <: VariableView

Creates a *fake* variable `y` such that `y = -x`. This variable behaves like an usual one.
"""
struct VarViewOpposite <: VariableView
    id::Int
    x::CPVariable
    domain::DomainViewOpposite
end

VarViewOffset(id::Int, x::CPVariable, c::Int) = VarViewOffset(id, x, c, DomainViewOffset(x.domain, c))
VarViewMul(id::Int, x::CPVariable, c::Int) = VarViewMul(id, x, c, DomainViewMul(x.domain, c))
VarViewOpposite(id::Int, x::CPVariable) = VarViewOpposite(id, x, DomainViewOpposite(x.domain))

assigned_value(x::VarViewOffset) = v + x.c
assigned_value(x::VarViewMul) = assigned_value(x.x) * x.c
assigned_value(x::VarViewOpposite) = -assigned_value(x.x)

isbound(dom::DomainView) = isbound(dom.inner)
Base.isempty(dom::DomainView) = isempty(dom.inner)
Base.length(dom::DomainView) = length(dom.inner)

Base.in(value::Int, dom::DomainViewOffset) = value - dom.c in dom.inner
Base.in(value::Int, dom::DomainViewMul) = (value % dom.c == 0 && (value ÷ dom.c) in dom.inner)
Base.in(value::Int, dom::DomainViewOpposite) = -value in dom.inner

reset_domain!(dom::DomainView) = reset_domain!(dom.inner)

remove!(dom::DomainViewOffset, value::Int) = remove!(dom.inner, value - dom.c)
remove!(dom::DomainViewMul, value::Int) = (value % dom.c != 0) ? false : remove!(dom.inner, value ÷ dom.c)
remove!(dom::DomainViewOpposite, value::Int) = remove!(dom.inner, -value)

remove_all!(dom::T) where {T<:DomainView} = remove_all!(dom.inner)

remove_above!(dom::DomainViewOffset, value::Int) = remove_above!(dom.inner, value - dom.c)
remove_above!(dom::DomainViewMul, value::Int) = remove_above!(dom.inner, convert(Int, floor(value / dom.c)))
remove_above!(dom::DomainViewOpposite, value::Int) = remove_below!(dom.inner, -value)

remove_below!(dom::DomainViewOffset, value::Int) = remove_below!(dom.inner, value - dom.c)
remove_below!(dom::DomainViewMul, value::Int) = remove_below!(dom.inner, convert(Int, ceil(value / dom.c)))
remove_below!(dom::DomainViewOpposite, value::Int) = remove_above!(dom.inner, -value)

remove_all_but!(dom::DomainViewOffset, value::Int) = remove_all_but!(dom.inner, value - dom.c)
remove_all_but!(dom::DomainViewMul, value::Int) = remove_all_but!(dom.inner, value ÷ dom.c)
remove_all_but!(dom::DomainViewOpposite, value::Int) = remove_all_but!(dom.inner, -value)

remove_between!(dom::DomainViewOffset, min::Int, max::Int) = remove_between!(dom.inner, min - dom.c, max - dom.c)
remove_between!(dom::DomainViewMul, min::Int, max::Int) =
    remove_between!(dom.inner, convert(Int, floor(min / dom.c)), convert(Int, ceil(max / dom.c)))
remove_between!(dom::DomainViewOpposite, min::Int, max::Int) = remove_between!(dom.inner, -max, -min)

assign!(dom::DomainViewOffset, value::Int) = assign!(dom.inner, value - dom.c)
assign!(dom::DomainViewMul, value::Int) = assign!(dom.inner, value ÷ dom.c)
assign!(dom::DomainViewOpposite, value::Int) = assign!(dom.inner, -value)

Base.minimum(dom::DomainViewOffset) = dom.c + minimum(dom.inner)
Base.minimum(dom::DomainViewMul) = dom.c * minimum(dom.inner)
Base.minimum(dom::DomainViewOpposite) = -1 * maximum(dom.inner)

Base.maximum(dom::DomainViewOffset) = dom.c + maximum(dom.inner)
Base.maximum(dom::DomainViewMul) = dom.c * maximum(dom.inner)
Base.maximum(dom::DomainViewOpposite) = -1 * minimum(dom.inner)

function iterate_domain_view(dom::DomainView, state::Int, transform::Function)
    returned = iterate(dom.inner, state)
    if isnothing(returned)
        return nothing
    end
    value, newState = returned
    return transform(value, dom), newState
end

Base.iterate(dom::DomainViewOffset, state = 1) = iterate_domain_view(dom, state, (value, dom) -> value + dom.c)
Base.iterate(dom::DomainViewMul, state = 1) = iterate_domain_view(dom, state, (value, dom) -> value * dom.c)
Base.iterate(dom::DomainViewOpposite, state = 1) = iterate_domain_view(dom, state, (value, _) -> -value)

@testitem "VarViewOffset()" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewOffset(2, x, 2)

    @test y.x == x
    @test y.id == 2
    @test y.c == 2
    @test y.domain.inner == x.domain

    u = JuLS.IntVariable(3, [4, 9, 11], trailer)
    v = JuLS.VarViewOffset(4, u, 3)

    @test v.x == u
    @test v.id == 4
    @test v.c == 3
    @test v.domain.inner == u.domain

    b = JuLS.BoolVariable(5, trailer)
    w = JuLS.VarViewOffset(6, b, 7)

    @test w.x == b
    @test w.id == 6
    @test w.c == 7
    @test w.domain.inner == b.domain
end

@testitem "in(::VarViewOffset)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewOffset(2, x, 2)

    @test !(1 in y.domain)
    @test 3 in y.domain
    @test 7 in y.domain
    @test !(8 in y.domain)

    u = JuLS.IntVariable(3, [4, 9, 11], trailer)
    v = JuLS.VarViewOffset(4, u, 3)

    @test !(4 in v.domain)

    values = [7, 12, 14]
    @test all(val -> val in v.domain, values)

    b = JuLS.BoolVariable(5, trailer)
    w = JuLS.VarViewOffset(6, b, 7)

    @test 7 in w.domain
    @test 8 in w.domain
    @test !(1 in w.domain)
    @test !(0 in w.domain)
end

@testitem "remove!(::DomainViewOffset)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewOffset(2, x, 2)

    @test !JuLS.remove!(y, 2)
    @test JuLS.remove!(y, 3)
    @test !(3 in y.domain)
    @test 4 in y.domain

    u = JuLS.IntVariable(3, [4, 9, 11], trailer)
    v = JuLS.VarViewOffset(4, u, 3)

    @test !JuLS.remove!(v, 4)
    @test JuLS.remove!(v, 14)
    @test JuLS.maximum(v.domain) == 12

    b = JuLS.BoolVariable(5, trailer)
    w = JuLS.VarViewOffset(6, b, 7)

    @test JuLS.remove!(w, 8)
    @test !JuLS.remove!(w, 0)
    @test JuLS.maximum(b.domain) == 0
end

@testitem "minimum(::DomainViewOffset)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)

    y = JuLS.VarViewOffset(2, x, 2)

    @test JuLS.minimum(y.domain) == 3

    JuLS.remove!(y, 3)

    @test JuLS.minimum(y.domain) == 4
end

@testitem "VarViewMul()" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewMul(2, x, 2)
    @test y.x == x
    @test y.id == 2
    @test y.c == 2
    @test y.domain.inner == x.domain

    b = JuLS.BoolVariable(5, trailer)
    w = JuLS.VarViewMul(6, b, 7)
    @test w.x == b
    @test w.id == 6
    @test w.c == 7
    @test w.domain.inner == b.domain
end

@testitem "in(::VarViewOffset)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewMul(2, x, 2)
    @test !(1 in y.domain)
    @test 6 in y.domain
    @test 8 in y.domain
    @test !(12 in y.domain)

    b = JuLS.BoolVariable(5, trailer)
    w = JuLS.VarViewMul(6, b, 7)
    @test 7 in w.domain
    @test 0 in w.domain
    @test !(1 in w.domain)
    @test !(8 in w.domain)
end

@testitem "remove!(::DomainViewOffset)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewMul(2, x, 2)
    @test !JuLS.remove!(y, 11)
    @test JuLS.remove!(y, 8)
    @test !(3 in y.domain)
    @test 6 in y.domain

    b = JuLS.BoolVariable(5, trailer)
    w = JuLS.VarViewMul(6, b, 7)
    @test !JuLS.remove!(w, 6)
    @test JuLS.remove!(w, 7)
    @test !(1 in b.domain)
    @test 0 in w.domain
end

@testitem "remove_above!(::DomainViewMul)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)

    y = JuLS.VarViewMul(2, x, 2)
    @test JuLS.remove_above!(y.domain, 3)
    @test length(y.domain) == 1

    b = JuLS.BoolVariable(5, trailer)
    w = JuLS.VarViewMul(6, b, 7)
    @test JuLS.remove_above!(w.domain, 4)
    @test 0 in w.domain
    @test !(1 in b.domain)
end

@testitem "remove_below!(::DomainViewMul)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)

    y = JuLS.VarViewMul(2, x, 2)
    @test JuLS.remove_below!(y.domain, 11)
    @test isempty(y.domain)

    b = JuLS.BoolVariable(5, trailer)
    w = JuLS.VarViewMul(6, b, 7)
    @test JuLS.remove_below!(w.domain, 4)
    @test 1 in b.domain
    @test !(0 in b.domain)
end

@testitem "remove_between!(::DomainViewMul)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)

    y = JuLS.VarViewMul(2, x, 2)
    @test JuLS.remove_between!(y.domain, 1, 12)
    @test isempty(y.domain)

    b = JuLS.BoolVariable(5, trailer)
    w = JuLS.VarViewMul(6, b, 7)
    @test JuLS.remove_between!(w.domain, -2, 6)
    @test 1 in b.domain
    @test !(0 in b.domain)
end

@testitem "remove_all_but!(::DomainViewMul)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewMul(2, x, 2)
    @test JuLS.remove_all_but!(y.domain, 12)
    @test length(y.domain) == 0

    u = JuLS.IntVariable(1, 1, 5, trailer)
    v = JuLS.VarViewMul(2, u, 2)
    @test JuLS.remove_all_but!(v.domain, 4)
    @test 4 in v.domain
end

@testitem "assign!(::DomainViewMul)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewMul(2, x, 2)
    JuLS.assign!(y.domain, 2)
    @test length(y.domain) == 1
    @test 2 in y.domain
end

@testitem "minimum(::DomainViewMul)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewMul(2, x, 2)
    @test JuLS.minimum(y.domain) == 2
    JuLS.remove!(y, 2)
    @test JuLS.minimum(y.domain) == 4
end

@testitem "maximum(::DomainViewMul)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewMul(2, x, 2)
    @test JuLS.maximum(y.domain) == 10
    JuLS.remove!(y, 10)
    @test JuLS.maximum(y.domain) == 8
end

@testitem "VarViewOpposite()" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewOpposite(1, x)

    @test y.x == x
    @test y.id == 1
    @test y.domain.inner == x.domain

    b = JuLS.BoolVariable(5, trailer)
    w = JuLS.VarViewOpposite(6, b)
    @test w.x == b
    @test w.id == 6
    @test w.domain.inner == b.domain
end

@testitem "in(::VarViewOpposite)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewOpposite(2, x)
    @test !(1 in y.domain)
    @test -1 in y.domain
    @test -5 in y.domain
    @test !(0 in y.domain)

    b = JuLS.BoolVariable(5, trailer)
    w = JuLS.VarViewOpposite(6, b)
    @test !(1 in w.domain)
    @test 0 in w.domain
    @test -1 in w.domain
end

@testitem "remove!(::DomainViewOpposite)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewOpposite(2, x)
    @test JuLS.remove!(y, -1)
    @test !JuLS.remove!(y, 1)
    @test !(-1 in y.domain)
    @test -2 in y.domain
end

@testitem "remove_above!(::DomainViewOpposite)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewOpposite(2, x)
    @test JuLS.remove_above!(y.domain, -4)
    @test length(y.domain) == 2
    @test -5 in y.domain && -4 in y.domain
end

@testitem "remove_below!(::DomainViewOpposite)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewOpposite(2, x)
    @test JuLS.remove_below!(y.domain, -4)
    @test length(y.domain) == 4
    vals = [-i for i ∈ 1:4]
    @test all(val -> val in y.domain, vals)
end

@testitem "remove_between!(::DomainViewOpposite)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewOpposite(2, x)
    @test JuLS.remove_between!(y.domain, -5, -1)
    @test length(y.domain) == 2
end

@testitem "remove_all_but!(::DomainViewOpposite)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewOpposite(2, x)
    @test JuLS.remove_all_but!(y.domain, -2)
    @test length(y.domain) == 1 && -2 in y.domain
end

@testitem "assign!(::DomainViewOpposite)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewOpposite(2, x)
    JuLS.assign!(y.domain, -5)
    @test length(y.domain) == 1 && -5 in y.domain

    u = JuLS.IntVariable(1, 1, 5, trailer)
    v = JuLS.VarViewOpposite(2, x)
    @test_throws AssertionError JuLS.assign!(y.domain, 1)
end

@testitem "minimum(::DomainViewOpposite)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewOpposite(2, x)
    @test JuLS.minimum(y.domain) == -5
    JuLS.remove!(y, -5)
    @test JuLS.minimum(y.domain) == -4
end

@testitem "maximum(::DomainViewOpposite)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewOpposite(2, x)
    @test JuLS.maximum(y.domain) == -1
    JuLS.remove!(y, -1)
    @test JuLS.maximum(y.domain) == -2
end

@testitem "iterate(::VarViewOpposite)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewOpposite(2, x)

    for (i, val) in enumerate(y.domain)
        @test -i == val
    end
end

@testitem "iterate(::DomainViewOffset)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewOffset(2, x, 2)

    for (i, val) in enumerate(y.domain)
        @test i + 2 == val
    end
end

@testitem "iterate(::DomainViewMul)" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 1, 5, trailer)
    y = JuLS.VarViewMul(2, x, 2)

    for (i, val) in enumerate(y.domain)
        @test i * 2 == val
    end
end

function Base.show(io::IO, var::T) where {T<:VariableView}
    print(io, id(var), " = ", var.domain)
end

function Base.show(io::IO, ::MIME"text/plain", var::T) where {T<:VariableView}
    print(io, typeof(var), ": ", id(var), " = ", var.domain)
end

function Base.show(io::IO, dom::T) where {T<:DomainView}
    print(io, "[", join(dom, " "), "]")
end

function Base.show(io::IO, ::MIME"text/plain", dom::T) where {T<:DomainView}
    print(io, typeof(dom), ": [", join(dom, " "), "]")
end