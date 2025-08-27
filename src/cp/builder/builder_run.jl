# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct CPBuilderRun <: RunMode

A specialized RunMode for building Constraint Programming (CP) models from a DAG structure.

# Fields
- `istouched::BitVector`: Flags for invariants to be processed
- `output_messages::Vector{DAGMessage}`: Output CPMessage of each invariant
- `converter::CPConverter`: Converter for translating invariants/variables to integer components
- `trailer::Trailer`: CP-specific state management object
"""
struct CPBuilderRun <: RunMode
    istouched::BitVector
    output_messages::Vector{DAGMessage}

    converter::CPConverter
    trailer::Trailer
end

function CPBuilderRun(decision_variables::Vector{DecisionVariable}, dag::DAG, converter::CPConverter, trailer::Trailer)
    @assert isinit(dag) "Cannot build CP Model if the DAG is not instantiated"

    cp_decision_variables = CPVariable[converter(var, trailer) for var in decision_variables]

    is_touched, messages = _default_initial_values(cp_decision_variables, dag)

    return CPBuilderRun(is_touched, messages, converter, trailer)
end

"""
    _default_initial_values(cp_decision_variables::Vector{CPVariable}, dag::DAG)

Initializes the state for CP model building by setting up tracking vectors and initial messages.

# Process
1. Creates tracking vectors
2. For each decision variable:
   - Identifies corresponding invariant
   - Marks invariant and its children
   - Creates initial CP variable message
"""
function _default_initial_values(cp_decision_variables::Vector{CPVariable}, dag::DAG)
    istouched = falses(length(dag))
    messages = Vector{DAGMessage}(undef, length(dag))
    for var in cp_decision_variables
        invariant_id = dag._var_to_first_invariants[var.id]
        _set_invariant_touched!(istouched, invariant_id)
        _set_invariant_touched!(istouched, children(dag._adjacency_matrix, invariant_id))
        messages[invariant_id] = CPVariableMessage(var)
    end
    return istouched, messages
end


"""
    run_dag!(run_mode::CPBuilderRun, dag::DAG)

Executes the CP model building process by traversing the DAG and creating CP elements.

# Process
For each touched invariant:
   - Builds CP elements
   - Stores resulting message
   - Marks children for processing if needed
"""
function run_dag!(run_mode::CPBuilderRun, dag::DAG)
    index = length(dag._var_to_first_invariants)
    while (index = findnext(istouched(run_mode), index + 1)) !== nothing
        new_message = build!(run_mode, dag, index)

        output_messages(run_mode)[index] = new_message

        if isnothing(cp_variable(new_message))
            continue
        end

        # Make sure children invariants will also be executed
        _set_invariant_touched!(istouched(run_mode), children(dag._adjacency_matrix, index))
    end
end

output_messages(run_mode::CPBuilderRun) = run_mode.output_messages
trailer(run_mode::CPBuilderRun) = run_mode.trailer
cp_converter(run_mode::CPBuilderRun) = run_mode.converter

cp_variable(run_mode::CPBuilderRun, index::Int) = cp_variable(output_messages(run_mode)[index])
cp_constraint(run_mode::CPBuilderRun, index::Int) = cp_constraint(output_messages(run_mode)[index])

"""
    are_parents_cp_variables(run_mode::CPBuilderRun, dag::DAG, index::Int)

Checks if all parent invariants of specified index have CP variables.
"""
are_parents_cp_variables(run_mode::CPBuilderRun, dag::DAG, index::Int) = all(
    parent -> istouched(run_mode)[parent] && !isnothing(cp_variable(run_mode, parent)),
    parents(dag._adjacency_matrix, index),
)

"""
    input_variables(run_mode::CPBuilderRun, dag::DAG, index::Int)

Collects CP variables from parent invariants if all these parents have a CPVariable in their output.
Otherwise returns nothing
"""
function input_variables(run_mode::CPBuilderRun, dag::DAG, index::Int)
    if invariant_using_cp(dag, index) && are_parents_cp_variables(run_mode, dag, index)
        return CPVariable[cp_variable(run_mode, parent) for parent in parents(dag._adjacency_matrix, index)]
    end
    return nothing
end

"""
    build!(run_mode::CPBuilderRun, dag::DAG, index::Int)

Build a CPMessage for specified invariant index.

# Process
1. Converts invariant to CP format (with integer values)
2. Collects input variables
3. Uses trailer for state management
4. Build the corresponding CPVariable/CPConstraint. 
"""
build!(run_mode::CPBuilderRun, dag::DAG, index::Int) = build!(
    cp_converter(run_mode)(invariant(dag, index)),
    input_variables(run_mode, dag, index),
    trailer(run_mode),
    index,
)

"""
    retrieve_variables_and_constraints(run_mode::CPBuilderRun, decision_indexes::Vector{Int})

Extracts all CP model components from the completed CPBuilderRun i.e. :
1. `decision_variables::Vector{CPVariable}`: Decision variables
2. `intermediate_variables::Vector{CPVariable}`: Intermediate variables
3. `inner_constraints::Vector{CPConstraint}`: Inherent constraint of intermediate variables (same length than `intermediate_variables`)
4. `transversal_constraints::Vector{CPConstraint}`: Other problem's constraints
"""
function retrieve_variables_and_constraints(run_mode::CPBuilderRun, decision_indexes::Vector{Int})
    decision_variables = CPVariable[]
    intermediate_variables = CPVariable[]
    inner_constraints = CPConstraint[]
    transversal_constraints = CPConstraint[]

    for index in decision_indexes
        push!(decision_variables, cp_variable(run_mode, index))
    end

    for index in modified_invariants(run_mode)
        if output_messages(run_mode)[index] isa IntermediateCPVariableMessage
            push!(intermediate_variables, cp_variable(run_mode, index))
            push!(inner_constraints, cp_constraint(run_mode, index))

        elseif output_messages(run_mode)[index] isa CPConstraintMessage
            push!(transversal_constraints, cp_constraint(run_mode, index))
        end
    end
    return decision_variables, intermediate_variables, inner_constraints, transversal_constraints
end

@testitem "CPBuilderRun()" begin
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
    trailer = JuLS.Trailer()
    run_mode = JuLS.CPBuilderRun(decision_variables, dag, JuLS.ClassicCPConverter(), trailer)

    for i = 1:8
        @test JuLS.cp_variable(run_mode, i).id == i
        @test JuLS.cp_variable(run_mode, i) isa JuLS.BoolVariable
    end
    @test run_mode.trailer == trailer
end

@testitem "run_dag!(::CPBuilderRun)" begin
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
    run_mode = JuLS.CPBuilderRun(decision_variables, dag, JuLS.ClassicCPConverter(), JuLS.Trailer())

    JuLS.run_dag!(run_mode, dag)

    @test all(run_mode.output_messages[i] isa JuLS.CPVariableMessage for i = 1:8)
    @test all(run_mode.output_messages[i] isa JuLS.IntermediateCPVariableMessage for i = 9:12)
    @test run_mode.output_messages[13] isa JuLS.CPConstraintMessage

    @test all(JuLS.cp_variable(run_mode, i) isa JuLS.BoolVariable for i = 1:12)
    @test all(JuLS.cp_constraint(run_mode, i) isa JuLS.Or for i = 9:12)
    @test JuLS.cp_constraint(run_mode, 13) isa JuLS.AmongUp
end

@testitem "retrieve_variables_and_constraints()" begin
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
    run_mode = JuLS.CPBuilderRun(decision_variables, dag, JuLS.ClassicCPConverter(), JuLS.Trailer())

    JuLS.run_dag!(run_mode, dag)

    x, intermediate_variables, inner_constraints, transversal_constraints =
        JuLS.retrieve_variables_and_constraints(run_mode, dag._var_to_first_invariants)

    @test length(x) == 8
    @test length(intermediate_variables) == length(inner_constraints) == 4
    @test length(transversal_constraints) == 1

    for i = 1:8
        @test x[i].id == i
        @test x[i] isa JuLS.BoolVariable
    end

    @test all(var -> var isa JuLS.BoolVariable, intermediate_variables)
    @test all(con -> con isa JuLS.Or, inner_constraints)
    @test transversal_constraints[1] isa JuLS.AmongUp

    @test inner_constraints[1].x == x[[7, 8]]
    @test inner_constraints[2].x == x[[5, 6]]
    @test inner_constraints[3].x == x[[3, 4]]
    @test inner_constraints[4].x == x[[1, 2]]

    @test transversal_constraints[1].x ==
          [inner_constraints[4].b, inner_constraints[3].b, inner_constraints[2].b, inner_constraints[1].b]
end