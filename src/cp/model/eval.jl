# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

const DEFAULT_TIME_LIMIT = 10

"""
    eval(model::CPLSModel, solution::Vector{Int}, decision_relaxed::Vector{Int})
Return all the feasible solutions if we relaxed all decision variables indexed by decision_relaxed and fix the other ones to the values in solution.
"""
function eval(model::CPLSModel, solution::Vector{Int}, decision_relaxed::Vector{Int})

    cp_run = init_cp_run(model, decision_relaxed)
    init!(cp_run.time_limit, DEFAULT_TIME_LIMIT)

    not_assigned_variables = apply_solution!(model, solution, decision_relaxed)

    update_on_domain_change!(not_assigned_variables)

    solve!(cp_run)

    reset_on_domain_change!(not_assigned_variables)

    restore_initial_state!(model.trailer)

    return cp_run.solutions
end


"""
    init_cp_run(model::CPLSModel, decision_relaxed::Vector{Int})

Init a CPRun with decision variables indexed by `decision_relaxed` as branchable variables. 
"""
function init_cp_run(model::CPLSModel, decision_relaxed::Vector{Int})
    cp_run = CPRun(model.trailer)

    for idx in decision_relaxed
        add_variable!(cp_run, model.decision_variables[idx].variable)
    end

    return cp_run
end


"""
    function update_on_domain_change!(variables::Vector{CPVariableContext})

Apply a fix_point to variable constraints from `variables` to remove *TEMPORARLY* infeasible values and non active constraints.
"""
function update_on_domain_change!(variables::Vector{CPVariableContext})
    constraints = CPConstraint[]

    for var in variables
        append!(constraints, var.variable.on_domain_change)
    end

    if !fix_point!(constraints)
        error("The current situation is infeasible")
    end

    for var in variables
        update_on_domain_change!(var)
    end
end


"""
    function reset_on_domain_change!(variables::Vector{CPVariableContext})

Resets all constraints related to variables contained in variables.
"""
function reset_on_domain_change!(variables::Vector{CPVariableContext})
    for var in variables
        reset_on_domain_change!(var)
    end
end


@testitem "eval(::CPLSModel)" begin
    trailer = JuLS.Trailer()
    x = Vector{JuLS.BoolVariable}(undef, 8)
    for i = 1:8
        x[i] = JuLS.BoolVariable(i, trailer)
    end
    decision_variables = JuLS.CPVariable[x...]

    y = Vector{JuLS.CPVariable}(undef, 4)
    constraints = Vector{JuLS.CPConstraint}(undef, 5)

    for i = 1:4
        y[i] = JuLS.BoolVariable(i + 8, trailer)
        constraints[i] = JuLS.Or(x[i*2-1:i*2], y[i], trailer)
    end
    constraints[5] = JuLS.AmongUp(y, JuLS.Singleton(1), 1, trailer)

    model = JuLS.CPLSModel(decision_variables, y, constraints[1:4], constraints[5:end], trailer)

    decision_relaxed = [1, 4, 7]

    current_solution = zeros(Int, 8)

    solutions = JuLS.eval(model, current_solution, decision_relaxed)

    @test solutions == [[1, 0, 0], [0, 1, 0], [0, 0, 1], [0, 0, 0]]

    #Test if every solution is feasible
    for sol in solutions
        new_solution = copy(current_solution)
        new_solution[decision_relaxed] = sol
        JuLS.apply_solution!(model, new_solution)
        @test JuLS.fix_point!(model.constraints)
        JuLS.restore_initial_state!(model.trailer)
    end

    # #Test an infeasible solution
    sol = [1, 1, 0]
    new_solution = copy(current_solution)
    new_solution[decision_relaxed] = sol
    JuLS.apply_solution!(model, new_solution)
    @test !JuLS.fix_point!(model.constraints)
    JuLS.restore_initial_state!(model.trailer)


    # #Check if variable.on_domain_change has changed
    for i = 1:8
        @test length(x[i].on_domain_change) == 1
    end
    for i = 1:4
        @test length(y[i].on_domain_change) == 2
    end
end