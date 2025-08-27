# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

include("variables.jl")

"""
    struct CPLSModel

- decision_variables::Vector{DecisionVariableContext}           : Vector of decision variables
- intermediate_variables::Vector{IntermediateVariableContext}   : Vector of intermediate variables
- constraints::Vector{CPConstraint}                             : Vector of constraints' problem
- trailer::Trailer                                              : Trailer linked to model's AbstractVariables

Interface between the Constraint Programming (CP) and Local Search (LS) model. Enables to efficiently apply the LocalSearch state to the CP variables. 
ATTENTION: the model must be initialized once all variables and constraints are set. 
"""
struct CPLSModel
    decision_variables::Vector{DecisionVariableContext}
    intermediate_variables::Vector{IntermediateVariableContext}
    constraints::Vector{CPConstraint}
    trailer::Trailer

    CPLSModel(trailer::Trailer) = new(DecisionVariableContext[], IntermediateVariableContext[], CPConstraint[], trailer)
end

include("apply.jl")
include("eval.jl")

CPLSModel() = CPLSModel(Trailer())

function add_decision_variable!(model::CPLSModel, x::CPVariable)
    push!(model.decision_variables, DecisionVariableContext(x))
end

function add_intermediate_variable!(model::CPLSModel, x::CPVariable, constraint::CPConstraint)
    push!(model.intermediate_variables, IntermediateVariableContext(x, constraint))
end

function add_constraint!(model::CPLSModel, constraint::CPConstraint)
    push!(model.constraints, constraint)
end

function clean_inactive_constraints!(model::CPLSModel)
    for var in vcat(model.decision_variables, model.intermediate_variables)
        clean_inactive_constraints!(var)
    end
end

function domains_cartesian_product(model::CPLSModel, decision_indexes::Vector{Int})
    cart_pdt = 1
    for idx in decision_indexes
        cart_pdt *= length(model.decision_variables[idx].variable.domain.values)
    end
    return cart_pdt
end

function CPLSModel(
    decision_variables::Vector{CPVariable},
    intermediate_variables::Vector{CPVariable},
    inner_constraints::Vector{CPConstraint},
    transversal_constraints::Vector{CPConstraint},
    trailer::Trailer,
)
    model = CPLSModel(trailer)
    init!(model, decision_variables, intermediate_variables, inner_constraints, transversal_constraints)
    return model
end

function init!(
    model::CPLSModel,
    decision_variables::Vector{CPVariable},
    intermediate_variables::Vector{CPVariable},
    inner_constraints::Vector{CPConstraint},
    transversal_constraints::Vector{CPConstraint},
)
    @assert length(intermediate_variables) == length(inner_constraints)

    constraints = vcat(inner_constraints, transversal_constraints)
    if !fix_point!(constraints)
        error("The model is infeasible")
    end
    for con in constraints
        if is_active(con)
            add_constraint!(model, con)
        end
    end

    for var in decision_variables
        add_decision_variable!(model, var)
    end

    for index = 1:length(intermediate_variables)
        if isbound(intermediate_variables[index])
            continue
        end
        add_intermediate_variable!(model, intermediate_variables[index], inner_constraints[index])
    end

    clean_inactive_constraints!(model)

    empty!(model.trailer)
end

@testitem "CPLSModel() constructor" begin
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

    @test length(model.decision_variables) == 8
    @test length(model.intermediate_variables) == 4
    @test length(model.constraints) == 5
    @test all(i -> model.decision_variables[i].variable == x[i], collect(1:8))
    @test all(i -> model.intermediate_variables[i].variable == y[i], collect(1:4))
    @test model.constraints == constraints
end