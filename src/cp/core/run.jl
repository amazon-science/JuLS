# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

const CPSolution = Vector{Int}

"""
mutable struct CPRun
    
    - branchable_variables::Vector{CPVariable}    : Array of branchable variables
    - constraints::Array{CPConstraint}            : Array of all the run's constraints
    - solutions::Vector{CPSolution}               : Array of solutions found
    - trailer::Trailer                            : trailer used for the search and solving
    - time_limit::TimeLimit                       : Time limit for the search

Instance of a CP enumeration where we branch on a specific set of decision variables. 
"""
mutable struct CPRun
    branchable_variables::Vector{CPVariable}
    constraints::Array{CPConstraint}
    solutions::Vector{CPSolution}
    trailer::Trailer
    time_limit::TimeLimit

    CPRun(trailer) = new(CPVariable[], CPConstraint[], CPSolution[], trailer, TimeLimit())
end

CPRun() = CPRun(Trailer())

"""
    add_variable!(run::CPRun, x::CPVariable; branchable=true)

Add a branchable variable to the CPRun.
"""
function add_variable!(cp_run::CPRun, x::CPVariable)

    push!(cp_run.branchable_variables, x)
end

"""
    add_constraint!(run::CPRun, constraint::CPConstraint)

Add a constraint to the CPRun.
"""
function add_constraint!(run::CPRun, constraint::CPConstraint)
    push!(run.constraints, constraint)
end

"""
    solutionFound(run::CPRun)

Return true if a solution was found and push this solution, i.e. every variable is bound, otherwise false
"""
function solutionFound(run::CPRun)
    solution = []
    for x in run.branchable_variables
        if !isbound(x)
            return false
        end
        push!(solution, assigned_value(x))
    end
    push!(run.solutions, solution)
    return true
end

"""
    Base.isempty(run::CPRun)::Bool

Return a boolean describing if the run is empty or not.
"""
function Base.isempty(run::CPRun)::Bool
    (
        isempty(run.branchable_variables) &&
        isempty(run.constraints) &&
        isempty(run.trailer.prior) &&
        isempty(run.trailer.current)
    )
end

"""
    reset_run!(run::CPRun)

Reset a given CPRun instance.
"""
function reset_run!(run::CPRun)
    restore_initial_state!(run.trailer)
    empty!(run.branchable_variables)
    empty!(run.constraints)
    run.solutions = CPSolution[]
end

"""
    domains_cartesian_product(run::CPRun)

Return the cartesian product of the run branchable variables: |D1|x|D2|x ... x|Dn|
"""
function domains_cartesian_product(run::CPRun)
    cart_pdt = 1
    for x in run.branchable_variables
        cart_pdt *= length(x.domain.values)
    end
    return cart_pdt
end


function display_solution_statistics(run::CPRun)
    potential_solutions = domains_cartesian_product(run)
    feasible_solutions = length(run.solutions)
    println("Potential solutions : ", potential_solutions)
    println(
        "Feasible solutions found : ",
        feasible_solutions,
        " ($(round(feasible_solutions/potential_solutions*100, digits=2))%)",
    )
end