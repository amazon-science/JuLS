# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    RunMode <: MoveEvaluatorOutput

Abstract type representing the mode of running a DAG evaluation.

# Subtypes
- InitRun : DAG initialization to set up initial invariant states.
- DeltaRun : Efficient evaluation of incremental changes (moves).
- FullRun : Complete evaluation of an assigment through the entire DAG
- OutputRun : Complete evaluation of an assigment for generating output and analysis.
- CPBuilderRun : Constraint Programming model construction mode.
"""
abstract type RunMode <: MoveEvaluatorOutput end

"""
    CommitableRunMode <: RunMode

Abstract type for run modes that can be committed to the DAG.
For now only DeltaRun is commitable 
"""
abstract type CommitableRunMode <: RunMode end

MoveEvaluatorOutput(run_mode::RunMode) = run_mode

eval(dag::DAG, input::MoveEvaluatorInput) = run_dag!(RunMode(input, dag), dag)


"""
    commit!(dag::DAG, r::CommitableRunMode)

Commits changes to the DAG state based on evaluation results.

# Behavior
- Applies changes to modified invariants
- Throws error if early stop occurred
"""
function commit!(dag::DAG, r::CommitableRunMode)
    if isearlystop(r)
        error("There was an early stop, not really possible to commit that move.")
    end

    for invariant_id in modified_invariants(r)
        commit!(r, invariant(dag, invariant_id), input_messages(r, invariant_id))
    end
end
commit!(dag::DAG, input::MoveEvaluatorInput) = commit!(dag, eval(dag, input))
commit!(dag::DAG, evaluated_move::EvaluatedMove) = commit!(dag, eval(dag, move(evaluated_move)))

commit!(::CommitableRunMode, invariant::Invariant, message::DAGMessage) = commit!(invariant, message)


RunMode(move::Move, dag::DAG) = DeltaRun(move, dag)
RunMode(decision_variables::DecisionVariablesArray, dag::DAG) = FullRun(decision_variables, dag)

istouched(r::RunMode) = r.istouched
input_messages(r::RunMode) = r.input_messages
input_messages(r::RunMode, invariant_id::Int) = input_messages(r)[invariant_id]
output(r::RunMode) = input_messages(r)[end]

modified_invariants(r::RunMode) = findall(istouched(r))

"""
    eval(r::RunMode, dag::DAG, index::Int)

Evaluates a single invariant in the DAG during execution of a specific run mode.
"""
eval(r::RunMode, dag::DAG, index::Int) = eval(invariant(dag, index), input_messages(r, index))
eval(::Invariant, ::NoMessage) = NoMessage()

"""
    _set_invariant_touched!(istouched::BitVector, invariant_id::Int)
    _set_invariant_touched!(istouched::BitVector, invariant_ids::Vector{Int})
    _set_invariant_touched!(istouched::BitVector, dag::DAG, input::MoveEvaluatorInput)

Internal functions for marking invariants that need to be evaluated during DAG execution.

# Process for MoveEvaluatorInput
1. Identifies impacted variables from input
2. For each impacted variable:
   - Marks its corresponding _DecisionVariableInvariant
   - Marks all dependent child invariants
3. Ensures proper propagation path
"""
_set_invariant_touched!(istouched::BitVector, invariant_id::Int) = (istouched[invariant_id] = 1)
_set_invariant_touched!(istouched::BitVector, invariant_ids::Vector{Int}) = (istouched[invariant_ids] .= 1)
function _set_invariant_touched!(istouched::BitVector, dag::DAG, input::MoveEvaluatorInput)
    for x in impacted_variables(input)
        istouched[dag._var_to_first_invariants[x.index]] = 1
        _set_invariant_touched!(istouched, children(dag._adjacency_matrix, dag._var_to_first_invariants[x.index]))
    end
end


"""
    _create_variable_message(input, variable::DecisionVariable, index::Int)

Internal function that creates appropriate message types for variables based on input type.

# Arguments
- `input`: Input type (Move, DecisionVariablesArray, or OutputInput)
- `variable::DecisionVariable`: The variable to create message for
- `index::Int`: Position in input (may differ from variable's index)

# Returns
Message type depends on input:
- Move → SingleVariableMoveDelta
- DecisionVariablesArray → SingleVariableMessage
- OutputInput → OutputMessage
"""
_create_variable_message(move::Move, x::DecisionVariable, index::Int) =
    SingleVariableMoveDelta(x.index, x.current_value, move.new_values[index])
_create_variable_message(::DecisionVariablesArray, x::DecisionVariable, ::Int) =
    SingleVariableMessage(x.index, x.current_value)
_create_variable_message(input::OutputInput, x::DecisionVariable, index::Int) = OutputMessage(
    _create_variable_message(input.best_variables, input.best_variables.variables[x.index], index),
    _create_variable_message(input.original_variables, input.original_variables.variables[x.index], index),
)

"""
    _default_initial_values(input::MoveEvaluatorInput, dag::DAG)

Creates initial state for DAG evaluation by setting up touched flags and input messages.

# Arguments
- `input::MoveEvaluatorInput`: Input triggering evaluation (Move, DecisionVariablesArray, etc.)
- `dag::DAG`: The DAG to be evaluated

# Returns
Tuple(BitVector, Vector{DAGMessage}):
1. `istouched`: BitVector marking which invariants need evaluation
2. `messages`: Vector of input messages for each invariant
"""
function _default_initial_values(input::MoveEvaluatorInput, dag::DAG)
    istouched = falses(length(dag))
    _set_invariant_touched!(istouched, [last_node_id(dag) - 1])

    _set_invariant_touched!(istouched, dag, input)

    messages = Vector{DAGMessage}(undef, length(dag))
    messages[last_node_id(dag)-1] = NoMessage()
    for (i, x) in enumerate(impacted_variables(input))
        messages[dag._var_to_first_invariants[x.index]] = _create_variable_message(input, x, i)
    end

    return istouched, messages
end

isearlystop(r::RunMode) = false
isearlystop(r::CommitableRunMode) = isinf(delta_obj(r))

"""
    run_dag!(run_mode::RunMode, dag::DAG)

Core function that executes DAG evaluation in the specified run mode.
Processes touched invariants and propagates messages through the DAG according to the topoligical ordering. 
"""

function run_dag!(run_mode::RunMode, dag::DAG)
    index = 0
    while (index = findnext(istouched(run_mode), index + 1)) !== nothing
        # Invariant evaluation
        new_message = eval(run_mode, dag, index)

        # If we identify that we should early stop, let's do it
        if shouldearlystop(new_message, dag)
            input_messages(run_mode)[last_node_id(dag)] = earlystopresult(run_mode)
            return run_mode
        end

        # If we don't have interesting messages to pass, just go to next iteration
        if iszero(new_message)
            continue
        end

        # Make sure children invariants will also be executed and make their input
        for child in children(dag._adjacency_matrix, index)
            make_input_message!(invariant(dag, child), child, input_messages(run_mode), new_message)
            _set_invariant_touched!(istouched(run_mode), child)
        end
    end

    return run_mode
end


@testitem "Testing eval" begin
    struct MockInvariant <: JuLS.Invariant end

    struct DummyDelta <: JuLS.Delta end

    JuLS.eval(invariant::MockInvariant, deltas::JuLS.DAGMessagesVector) = DummyDelta()
    JuLS.eval(invariant::MockInvariant, deltas::JuLS.SingleVariableMoveDelta) = DummyDelta()

    invariant1 = MockInvariant()
    invariant2 = MockInvariant()
    invariant3 = MockInvariant()
    invariant4 = MockInvariant()

    dag = JuLS.DAG(1) # picture of the test DAG below 😀

    #        invariant1 
    #           /  \
    #          /    \
    #         /      \
    # invariant2    invariant3
    #         \      /
    #          \    /
    #           \  /
    #        invariant4

    JuLS.add_invariant!(dag, invariant1; variable_parent_indexes = [1])
    JuLS.add_invariant!(dag, invariant2; invariant_parent_indexes = [2], name = "2")
    JuLS.add_invariant!(dag, invariant3; invariant_parent_indexes = [2], name = "3")
    JuLS.add_invariant!(dag, invariant4; invariant_parent_indexes = [3, 4], name = "4")

    JuLS.init!(dag)

    dummy_move = JuLS.Move([JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(1))], [JuLS.BinaryDecisionValue(1)])

    @test JuLS.output(JuLS.eval(dag, dummy_move)) == DummyDelta()

    @test JuLS.modified_invariants(JuLS.eval(dag, dummy_move)) == [1, 2, 3, 4, 5, 6]
end

@testitem "Testing early stop" begin
    mutable struct InvariantCounter <: JuLS.Invariant
        count::Int
    end

    struct DummyDelta <: JuLS.Delta end

    function JuLS.eval(invariant::InvariantCounter, t::JuLS.DAGMessagesVector)
        invariant.count += 1
        return JuLS.ConstraintDelta(1000)
    end
    function JuLS.eval(
        invariant::InvariantCounter,
        ::JuLS.DAGMessagesVector{JuLS.SingleVariableMoveDelta{JuLS.BinaryDecisionValue}},
    )
        invariant.count += 1
        return DummyDelta()
    end

    invariant1 = InvariantCounter(0)
    invariant2 = InvariantCounter(0)
    invariant3 = InvariantCounter(0)
    invariant4 = InvariantCounter(0)

    dag = JuLS.DAG(1) # picture of the test DAG below 😀

    #        invariant1 
    #           /  \
    #          /    \
    #         /      \
    # invariant2    invariant3
    #         \      /
    #          \    /
    #           \  /
    #        invariant4

    JuLS.add_invariant!(dag, invariant1; variable_parent_indexes = [1])
    JuLS.add_invariant!(dag, invariant2; invariant_parent_indexes = [2])
    JuLS.add_invariant!(dag, invariant3; invariant_parent_indexes = [2])
    JuLS.add_invariant!(dag, invariant4; invariant_parent_indexes = [3, 4])

    JuLS.init!(dag)

    dummy_move = JuLS.Move([JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(1))], [JuLS.BinaryDecisionValue(1)])
    result = JuLS.eval(dag, dummy_move)

    @test isa(result, JuLS.DeltaRun)
    @test JuLS.output(result) == JuLS.ResultDelta(typemax(Float64), false)

    # We check that only some invariants got called.
    @test invariant1.count == 1
    @test invariant2.count == 1
    @test invariant3.count == 0
    @test invariant4.count == 0

    @test_throws ErrorException("There was an early stop, not really possible to commit that move.") JuLS.commit!(
        dag,
        result,
    )
end

@testitem "Testing early stop threshold" begin
    mutable struct InvariantCounter <: JuLS.Invariant
        count::Int
    end

    struct DummyDelta <: JuLS.Delta end

    function JuLS.eval(invariant::InvariantCounter, ::DummyDelta)
        invariant.count += 1
        return JuLS.ConstraintDelta(JuLS.EARLY_STOP_CONSTRAINT_THRESHOLD - 1)
    end
    function JuLS.eval(invariant::InvariantCounter, ::JuLS.DAGMessagesVector)
        invariant.count += 1
        return JuLS.ConstraintDelta(JuLS.EARLY_STOP_CONSTRAINT_THRESHOLD - 1)
    end
    function JuLS.eval(invariant::InvariantCounter, ::JuLS.SingleVariableMoveDelta)
        invariant.count += 1
        return DummyDelta()
    end

    invariant1 = InvariantCounter(0)
    invariant2 = InvariantCounter(0)
    invariant3 = InvariantCounter(0)
    invariant4 = InvariantCounter(0)

    dag = JuLS.DAG(1) # picture of the test DAG below 😀

    #        invariant1 
    #           /  \
    #          /    \
    #         /      \
    # invariant2    invariant3
    #         \      /
    #          \    /
    #           \  /
    #        invariant4

    JuLS.add_invariant!(dag, invariant1; variable_parent_indexes = [1])
    JuLS.add_invariant!(dag, invariant2; invariant_parent_indexes = [2])
    JuLS.add_invariant!(dag, invariant3; invariant_parent_indexes = [2])
    JuLS.add_invariant!(dag, invariant4; invariant_parent_indexes = [3, 4])

    JuLS.init!(dag)

    dummy_move = JuLS.Move([JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(1))], [JuLS.BinaryDecisionValue(1)])
    @test JuLS.output(JuLS.eval(dag, dummy_move)) == JuLS.ConstraintDelta(JuLS.EARLY_STOP_CONSTRAINT_THRESHOLD - 1)

    # We check that all invariants got called: no early stop since it is below the threshold
    @test invariant1.count == 1
    @test invariant2.count == 1
    @test invariant3.count == 1
    @test invariant4.count == 1

end