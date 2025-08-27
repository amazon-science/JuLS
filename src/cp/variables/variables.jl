# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

abstract type CPVariable end
abstract type Domain end

include("intdomain.jl")
include("intvariable.jl")
include("booldomain.jl")
include("boolvariable.jl")
include("view.jl")

"""
    isbound(x::CPVariable)

Check whether x has an assigned value.
"""
isbound(x::CPVariable) = length(x.domain) == 1

"""
    assign!(x::CPVariable, value::Int)

Remove everything from the domain of `x` but `value`.
"""
assign!(x::CPVariable, value::Int) = assign!(x.domain, value)
remove!(x::CPVariable, value::Int) = remove!(x.domain, value)

"""
    assigned_value(x::CPVariable)

Return the assigned value of `x`. Throw an error if `x` is not bound.
"""
function assigned_value(x::CPVariable)
    @assert isbound(x)
    return minimum(x.domain)
end

id(var::CPVariable) = "x[$(var.id)]"