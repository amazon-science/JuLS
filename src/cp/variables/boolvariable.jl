# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct BoolVariable <: AbstractVar

A "simple" boolean variable.
The constraints that affect this variable are stored in the `on_domain_change` array.
"""
mutable struct BoolVariable <: CPVariable
    id::Int
    domain::BoolDomain
    on_domain_change::Array{CPConstraint}
end

"""
    function BoolVariable(index::Int, trailer::Trailer)

Create a `BoolVariable` with a domain being equal to [false, true] with the `id` int identifier
and that will be backtracked by `trailer`.
"""
function BoolVariable(id::Int, trailer::Trailer)
    dom = BoolDomain(trailer)

    return BoolVariable(id, dom, CPConstraint[])
end
BoolVariable(trailer::Trailer) = BoolVariable(0, trailer)

function Base.show(io::IO, var::BoolVariable)
    print(io, id(var), " = ", var.domain)
end

function Base.show(io::IO, ::MIME"text/plain", var::BoolVariable)
    print(io, typeof(var), ": ", id(var), " = ", var.domain)
end


"""
    assign!(x::BoolVariable, value::Bool)

Remove everything from the domain of `x` but `value`.
"""
assign!(x::BoolVariable, value::Bool) = assign!(x.domain, value)

remove!(x::BoolVariable, value::Bool) = remove!(x.domain, value)

"""
    assigned_value(x::BoolVariable)

Return the assigned value of `x`. Throw an error if `x` is not bound.
"""
function assigned_value(x::BoolVariable)
    @assert isbound(x)

    return convert(Bool, minimum(x.domain.inner))
end

