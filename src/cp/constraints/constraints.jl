# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

include("utils/utils.jl")

include("equal.jl")
include("among_up.jl")
include("among.jl")
include("atmost.jl")
include("elementbc.jl")
include("elementdc.jl")
include("isdifferent.jl")
include("or.jl")
include("sumlessthan.jl")
include("notequal.jl")

is_active(constraint::CPConstraint) = constraint.active.value

"""
    add_on_domain_change!(x::CPVariable, constraint::CPConstraint)

Make sure `constraint` will be propagated if `x`'s domain changes. 
"""
function add_on_domain_change!(x::CPVariable, constraint::CPConstraint)
    if !(constraint in x.on_domain_change)
        push!(x.on_domain_change, constraint)
    end
end

add_on_domain_change!(x::VariableView, constraint::CPConstraint) = add_on_domain_change!(x.x, constraint)


function add_on_domain_change!(constraint::CPConstraint)
    for x in variables(constraint)
        if !isbound(x)
            add_on_domain_change!(x, constraint)
        end
    end
end

"""
    add_to_propagate!(to_propagate::Set{CPConstraint}, constraints::Array{CPConstraint})

Add the constraints to `to_propagate` only if they are active.
"""
function add_to_propagate!(to_propagate::Set{<:CPConstraint}, constraints::Array{<:CPConstraint})
    for constraint in constraints
        if is_active(constraint)
            push!(to_propagate, constraint)
        end
    end
end

"""
    trigger_domain_change!(to_propagate::Set{CPConstraint}, x::CPVariable)

Add the constraints that have to be propagated when the domain of `x` changes to `to_propagate`.
"""
trigger_domain_change!(to_propagate::Set{<:CPConstraint}, x::CPVariable) =
    add_to_propagate!(to_propagate, get_on_domain_change(x))

get_on_domain_change(x::CPVariable) = x.on_domain_change

get_on_domain_change(x::VariableView) = x.x.on_domain_change
