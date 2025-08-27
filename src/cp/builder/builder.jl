# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

include("converter/converter.jl")
include("cp_message.jl")
include("constraints/constraints.jl")
include("builder_run.jl")

"""
    init_cp_model(
        decision_variables::Vector{DecisionVariable},
        dag::DAG,
        converter::CPConverter = ClassicCPConverter(),
        trailer::Trailer = Trailer()
    )

Creates and initializes a Constraint Programming model from a DAG structure.
"""
function init_cp_model(
    decision_variables::Vector{DecisionVariable},
    dag::DAG,
    converter::CPConverter = ClassicCPConverter(),
    trailer::Trailer = Trailer(),
)
    model = CPLSModel(trailer)
    init!(model, decision_variables, dag, converter)
    return model
end

"""
init!(model::CPLSModel,
decision_variables::Vector{DecisionVariable},
dag::DAG,
converter::CPConverter)

Initializes a CPLSModel with components translated from a DAG structure thanks to a CPBuilderRun.
"""
function init!(model::CPLSModel, decision_variables::Vector{DecisionVariable}, dag::DAG, converter::CPConverter)
    run_mode = JuLS.CPBuilderRun(decision_variables, dag, converter, model.trailer)
    JuLS.run_dag!(run_mode, dag)

    decision_variables, intermediate_variables, inner_constraints, transversal_constraints =
        retrieve_variables_and_constraints(run_mode, dag._var_to_first_invariants)

    init!(model, decision_variables, intermediate_variables, inner_constraints, transversal_constraints)
end

@testitem "init_cp_model()" begin
    dag = JuLS.DAG(8)

    or_invariant_ids = Int[
        JuLS.add_invariant!(dag, JuLS.OrInvariant(); variable_parent_indexes = [(i * 2) - 1, i * 2], using_cp = true) for i = 1:4
    ]

    JuLS.add_invariant!(
        dag,
        JuLS.CompositeInvariant([JuLS.AmongInvariant(JuLS.Singleton(true)), JuLS.ComparatorInvariant(1)]);
        invariant_parent_indexes = or_invariant_ids,
        using_cp = true,
    )

    decision_variables = JuLS.DecisionVariable[JuLS.DecisionVariable(i, false) for i = 1:8]
    JuLS.init!(dag, JuLS.DecisionVariablesArray(decision_variables))
    cp_model = JuLS.init_cp_model(decision_variables, dag, JuLS.ClassicCPConverter(), JuLS.Trailer())

    @test length(cp_model.decision_variables) == 8
    @test length(cp_model.intermediate_variables) == 4
    @test length(cp_model.constraints) == 5
end

