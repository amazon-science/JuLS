# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    abstract type CPVariableContext

Constraint Programming Variable Context. Contains the corresponding CPVariable used for CP solving 
and additional informations depending if it's a decision or intermediate variable
"""
abstract type CPVariableContext end


"""
    mutable struct DecisionVariableContext <: CPVariableContext

Decision variable for local search.

- variable::CPVariable                      : Corresponding CP variable
- current_value::Int                        : Current value for local search
- selected::Bool                            : Is the variable selected for CP solving
- initial_constraints::Vector{CPConstraint}   : Initial active constraints
"""
mutable struct DecisionVariableContext <: CPVariableContext
    variable::CPVariable
    initial_constraints::Vector{CPConstraint}

    DecisionVariableContext(x::CPVariable) = new(x, copy(get_on_domain_change(x)))
end


"""
    mutable struct IntermediateVariableContext <: CPVariableContext

Intermediate variable for local search.

- variable::CPVariable              : Corresponding CP variable
- inner_constraint::CPConstraint      : Inner constraint defining this variable. If the parents variable are assigned this constraint enables to assign the intermdiate variable
- initial_constraints::Vector{CPConstraint}   : Initial active constraints
"""
mutable struct IntermediateVariableContext <: CPVariableContext
    variable::CPVariable
    inner_constraint::CPConstraint
    initial_constraints::Vector{CPConstraint}

    IntermediateVariableContext(x::CPVariable, inner_constraint::CPConstraint) =
        new(x, inner_constraint, copy(get_on_domain_change(x)))
end

"""
    function clean_inactive_constraints!(var::CPVariableContext)

Remove definitively the inactive constraints of CPVariableContext `var`.
"""
function clean_inactive_constraints!(var::CPVariableContext)
    new_constraints = CPConstraint[]
    for con in var.initial_constraints
        if con.active.value
            push!(new_constraints, con)
        end
    end
    var.initial_constraints = new_constraints
    update_on_domain_change!(var)
end
"""
    function update_on_domain_change!(var::CPVariableContext)

Update the on_domain_change field of the corresponding CPVariable of `var`. Keeps only the active constraints 
"""
function update_on_domain_change!(var::CPVariableContext)
    x = var.variable
    empty!(x.on_domain_change)
    for con in var.initial_constraints
        if con.active.value
            push!(x.on_domain_change, con)
        end
    end
end


"""
    function reset_on_domain_change!(var::CPVariableContext)

Reset CPVariableContext used for CP.
Reset the corresponding CP variable on_domain_change with initial constraints. 
"""
function reset_on_domain_change!(var::CPVariableContext)
    var.variable.on_domain_change = copy(var.initial_constraints)
end


function Base.show(io::IO, var::CPVariableContext)
    print(io, var.variable)
end

function Base.show(io::IO, ::MIME"text/plain", var::CPVariableContext)
    print(io, var.variable)
end


@testitem "clean_inactive_constraints!()" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 3, trailer)
    y = JuLS.IntVariable(2, 4, trailer)
    z = JuLS.IntVariable(3, 7, trailer)

    c1 = JuLS.Equal(x, y, trailer)
    c2 = JuLS.AtMost(JuLS.CPVariable[y, z], 2, 1, trailer)

    JuLS.fix_point!([c1, c2])

    ls_y = JuLS.DecisionVariableContext(y)

    JuLS.clean_inactive_constraints!(ls_y)

    @test length(ls_y.initial_constraints) == 1
    @test ls_y.initial_constraints[1] == c1
end

@testitem "update_on_domain_change!()" begin
    trailer = JuLS.Trailer()
    x = JuLS.IntVariable(1, 3, trailer)
    y = JuLS.IntVariable(2, 4, trailer)
    z = JuLS.IntVariable(3, 7, trailer)

    c1 = JuLS.Equal(x, y, trailer)
    c2 = JuLS.AtMost(JuLS.CPVariable[y, z], 2, 1, trailer)

    ls_y = JuLS.DecisionVariableContext(y)

    JuLS.fix_point!([c1, c2])

    @test length(y.on_domain_change) == 2
    @test length(ls_y.initial_constraints) == 2

    JuLS.update_on_domain_change!(ls_y)

    @test length(y.on_domain_change) == 1
    @test y.on_domain_change[1] == c1
end