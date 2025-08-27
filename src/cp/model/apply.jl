# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    function apply_solution!(model::CPLSModel)

Assign decision variables according to the values in solution if they are not relaxed. 
Assign intermediate variables according to their inner constraints if they can be assigned according to their parent variables.
Return all the CPVariableContext not assigned.
"""
function apply_solution!(model::CPLSModel, solution::Vector{Int}, decision_relaxed::Vector{Int} = Int[])

    is_decision_relaxed = falses(length(model.decision_variables))
    is_decision_relaxed[decision_relaxed] .= true

    not_assigned_variables = CPVariableContext[]
    for var in model.decision_variables
        if is_decision_relaxed[var.variable.id]
            push!(not_assigned_variables, var)
        else
            assign!(var.variable, solution[var.variable.id])
        end
    end

    for var in model.intermediate_variables
        if apply!(var.inner_constraint)
            if isempty(var.variable.domain)
                @error "The current decision values are infeasible"
            end
        else
            push!(not_assigned_variables, var)
        end
    end
    return not_assigned_variables
end

@testitem "apply_solution()" begin
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

    solution = zeros(Int, 8)

    not_assigned_variables = JuLS.apply_solution!(model, solution, decision_relaxed)

    @test length(not_assigned_variables) == 3 + 3

    ids = [1, 4, 7, 9, 10, 12]

    for (i, var) in enumerate(not_assigned_variables)
        @test var.variable.id == ids[i]
        @test !JuLS.isbound(var.variable)
    end

    decision_fixed = [2, 3, 5, 6, 8]
    for i in decision_fixed
        @test JuLS.assigned_value(model.decision_variables[i].variable) == 0
    end

    intermediate_fixed = 11
    for i in intermediate_fixed
        @test JuLS.assigned_value(model.intermediate_variables[i-8].variable) == 0
    end
end

