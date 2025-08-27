# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct IntVariable <: CPVariable

A "simple" integer variable, whose domain can be any set of integers.
The constraints that affect this variable are stored in the `on_domain_change` array.
"""
mutable struct IntVariable <: CPVariable
    id::Int
    domain::IntDomain
    on_domain_change::Array{CPConstraint}
end

"""
    function IntVariable(id::Int, min::Int, max::Int, trailer::Trailer)

Create an `IntVariable` with a domain being the integer range [`min`, `max`] with the `id` int identifier
and that will be backtracked by `trailer`.
"""
function IntVariable(id::Int, min::Int, max::Int, trailer::Trailer)
    offset = min - 1
    dom = IntDomain(trailer, max - min + 1, offset)

    return IntVariable(id, dom, CPConstraint[])
end
IntVariable(min::Int, max::Int, trailer::Trailer) = IntVariable(0, min, max, trailer)

"""
    function IntVariable(id::Int, values::Vector{Int} trailer::Trailer)

Create an `IntVariable` with a domain being `values` with the `id` int identifier
and that will be backtracked by `trailer`.
"""
IntVariable(id::Int, values::Vector{Int}, trailer::Trailer) =
    IntVariable(id, IntDomain(trailer, unique(values)), CPConstraint[])
IntVariable(values::Vector{Int}, trailer::Trailer) = IntVariable(0, values, trailer)

function Base.show(io::IO, var::IntVariable)
    print(io, id(var), " = ", var.domain)
end

function Base.show(io::IO, ::MIME"text/plain", var::IntVariable)
    print(io, typeof(var), ": ", id(var), " = ", var.domain)
end