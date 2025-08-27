# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct OutputRun <: RunMode

Run mode for generating output and analysis in DAG evaluation.
Compares the evaluation of initial and final (or best) solution.
"""
struct OutputRun <: RunMode
    input::OutputInput
    istouched::BitVector
    input_messages::Vector{DAGMessage}
end
function OutputRun(input::OutputInput, dag::DAG)
    istouched, messages = _default_initial_values(input, dag)
    if !ispath(input.path)
        mkpath(input.path)
    end
    _set_files(input.path) # Setting output files.

    return OutputRun(input, istouched, messages)
end
RunMode(input::OutputInput, dag::DAG) = OutputRun(input, dag)

struct OutputMessage <: DAGMessage
    best_message::DAGMessage
    original_message::DAGMessage
end

# Needs duplicated code to lift ambiguity
_init_message(t::SingleType, first_message::OutputMessage) =
    OutputMessage(_init_message(t, first_message.best_message), _init_message(t, first_message.original_message))
_init_message(t::VectorType, first_message::OutputMessage) =
    OutputMessage(_init_message(t, first_message.best_message), _init_message(t, first_message.original_message))
_init_message(t::MultiType, first_message::OutputMessage) =
    OutputMessage(_init_message(t, first_message.best_message), _init_message(t, first_message.original_message))

function _append_message!(current_message::OutputMessage, message::OutputMessage)
    _append_message!(current_message.best_message, message.best_message)
    _append_message!(current_message.original_message, message.original_message)
end

output_path(r::OutputRun) = r.input.path

function eval(r::OutputRun, dag::DAG, index::Int)
    input_message = input_messages(r, index)
    current_invariant = invariant(dag, index)

    return output(current_invariant, input_message, output_path(r), helper(dag); name = invariant_name(dag, index))
end

abstract type FeasibilityEvaluation end
struct NoConstraint <: FeasibilityEvaluation end
struct HardConstraint <: FeasibilityEvaluation end

FeasibilityEvaluation(::Invariant) = NoConstraint()

_isbrokenconstraint(invariant::Invariant, result::DAGMessage) =
    _isbrokenconstraint(FeasibilityEvaluation(invariant), result)

_isbrokenconstraint(::NoConstraint, ::DAGMessage) = false
_isbrokenconstraint(::HardConstraint, result::DAGMessage) = result.value > 0

"""
    output(
        invariant::Invariant,
        message::OutputMessage,
        output_path::String,
        helper::AbstractDAGHelper;
        name::Union{String,Nothing} = nothing
    )

Processes and writes invariant evaluation results during OutputRun execution 

# Process Flow
1. Evaluates invariant with best solution message and original solution message
2. Writes results to invariants.csv, if values differ, writes to modified_invariants.csv
3. Adds broken constraint to broken_constraints.csv
"""
function output(
    invariant::Invariant,
    message::OutputMessage,
    output_path::String,
    ::AbstractDAGHelper;
    name::Union{String,Nothing} = nothing,
)
    best_value = eval(invariant, message.best_message)
    original_value = eval(invariant, message.original_message)

    write_invariant_file(output_string(best_value), output_string(original_value), name, output_path)

    if _isbrokenconstraint(invariant, best_value)
        if isnothing(name)
            @warn "An invariant is an hard constraint and has no name"
            name = "nothing"
        end
        CSV.write(broken_constraints_filename(output_path), DataFrame(broken_constraints = [name]); append = true)
    end

    return OutputMessage(best_value, original_value)
end

write_invariant_file(::Nothing, ::Nothing, ::Nothing, ::String) = nothing
write_invariant_file(::Nothing, ::Nothing, ::String, ::String) = nothing
write_invariant_file(::String, ::String, ::Nothing, ::String) = nothing
function write_invariant_file(best_value::String, original_value::String, invariant_name::String, output_path::String)
    CSV.write(
        invariant_filename(output_path),
        DataFrame(invariant_name = [invariant_name], old_value = [original_value], new_value = [best_value]);
        append = true,
    )
    if best_value == original_value
        return
    end
    CSV.write(
        modified_invariant_filename(output_path),
        DataFrame(invariant_name = [invariant_name], old_value = [original_value], new_value = [best_value]);
        append = true,
    )
end

invariant_filename(output_path::String) = joinpath(output_path, "invariants.csv")
modified_invariant_filename(output_path::String) = joinpath(output_path, "modified_invariants.csv")
broken_constraints_filename(output_path::String) = joinpath(output_path, "broken_constraints.csv")

function _set_files(output_path::String)
    CSV.write(invariant_filename(output_path), DataFrame(invariant_name = [], old_value = [], new_value = []);)
    CSV.write(modified_invariant_filename(output_path), DataFrame(invariant_name = [], old_value = [], new_value = []);)
end

@testitem "Testing output function" begin
    using CSV
    using DataFrames
    mutable struct MockInvariant <: JuLS.Invariant
        nb_of_eval::Int
    end

    function JuLS.eval(i::MockInvariant, ::JuLS.DecisionVariablesArray)
        i.nb_of_eval += 1
        return JuLS.FloatFullMessage(i.nb_of_eval)
    end

    invariant = MockInvariant(0.0)
    test_path = joinpath(JuLS.PROJECT_ROOT, "dummy_folder_for_test0")

    @test JuLS.output(
        invariant,
        JuLS.OutputMessage(JuLS.DecisionVariablesArray([]), JuLS.DecisionVariablesArray([])),
        test_path,
        JuLS.NoHelper(),
    ) == JuLS.OutputMessage(JuLS.FloatFullMessage(1.0), JuLS.FloatFullMessage(2.0))
end

@testitem "Testing eval with output unchanged" begin
    using CSV
    using DataFrames
    mutable struct MockInvariant <: JuLS.Invariant
        nb_of_eval::Int
    end

    JuLS.InputType(::MockInvariant) = JuLS.SingleType()

    function JuLS.eval(i::MockInvariant, ::JuLS.SingleVariableMessage)
        return JuLS.FloatFullMessage(i.nb_of_eval)
    end

    invariant = MockInvariant(0.0)

    dag = JuLS.DAG(1)

    JuLS.add_invariant!(dag, invariant; variable_parent_indexes = [1], name = "dummy_invariant")

    JuLS.init!(dag)

    test_path = joinpath(JuLS.PROJECT_ROOT, "dummy_folder_for_test1")

    input = JuLS.OutputInput(
        JuLS.DecisionVariablesArray([JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(1))]),
        JuLS.DecisionVariablesArray([JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(1))]),
        test_path,
    )

    JuLS.eval(dag, input)

    invariants_df = CSV.read(JuLS.invariant_filename(test_path), DataFrame)
    modified_invariants_df = CSV.read(JuLS.modified_invariant_filename(test_path), DataFrame)

    rm(test_path, recursive = true)

    @test names(invariants_df) == ["invariant_name", "old_value", "new_value"]
    @test names(modified_invariants_df) == ["invariant_name", "old_value", "new_value"]

    @test invariants_df.invariant_name == ["dummy_invariant"]
    @test modified_invariants_df.invariant_name == []

    @test invariants_df.old_value == [0.0]
    @test modified_invariants_df.old_value == []

    @test invariants_df.new_value == [0.0]
    @test modified_invariants_df.new_value == []
end

@testitem "Testing eval with output changed" begin
    using CSV
    using DataFrames
    mutable struct MockInvariant <: JuLS.Invariant
        nb_of_eval::Int
    end
    JuLS.InputType(::MockInvariant) = JuLS.SingleType()

    function JuLS.eval(i::MockInvariant, ::JuLS.SingleVariableMessage)
        i.nb_of_eval += 1
        return JuLS.FloatFullMessage(i.nb_of_eval)
    end

    invariant = MockInvariant(0.0)

    dag = JuLS.DAG(1)

    JuLS.add_invariant!(dag, invariant; variable_parent_indexes = [1], name = "dummy_invariant")

    JuLS.init!(dag)

    test_path = joinpath(JuLS.PROJECT_ROOT, "dummy_folder_for_test2")

    input = JuLS.OutputInput(
        JuLS.DecisionVariablesArray([JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(1))]),
        JuLS.DecisionVariablesArray([JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(1))]),
        test_path,
    )

    JuLS.eval(dag, input)

    invariants_df = CSV.read(JuLS.invariant_filename(test_path), DataFrame)
    modified_invariants_df = CSV.read(JuLS.modified_invariant_filename(test_path), DataFrame)

    rm(test_path, recursive = true)

    @test names(invariants_df) == ["invariant_name", "old_value", "new_value"]
    @test names(modified_invariants_df) == ["invariant_name", "old_value", "new_value"]

    @test invariants_df.invariant_name == ["dummy_invariant"]
    @test modified_invariants_df.invariant_name == ["dummy_invariant"]

    @test invariants_df.old_value == [2.0]
    @test modified_invariants_df.old_value == [2.0]

    @test invariants_df.new_value == [1.0]
    @test modified_invariants_df.new_value == [1.0]

    # Doing it twice to make sure the appending is working properly
    input = JuLS.OutputInput(
        JuLS.DecisionVariablesArray([JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(1))]),
        JuLS.DecisionVariablesArray([JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(1))]),
        test_path,
    )

    JuLS.eval(dag, input)

    invariants_df = CSV.read(JuLS.invariant_filename(test_path), DataFrame)
    modified_invariants_df = CSV.read(JuLS.modified_invariant_filename(test_path), DataFrame)

    rm(test_path, recursive = true)

    @test names(invariants_df) == ["invariant_name", "old_value", "new_value"]
    @test names(modified_invariants_df) == ["invariant_name", "old_value", "new_value"]

    @test invariants_df.invariant_name == ["dummy_invariant"]
    @test modified_invariants_df.invariant_name == ["dummy_invariant"]

    @test invariants_df.old_value == [4.0]
    @test modified_invariants_df.old_value == [4.0]

    @test invariants_df.new_value == [3.0]
    @test modified_invariants_df.new_value == [3.0]
end

@testitem "Testing eval without a name" begin
    using CSV
    using DataFrames
    mutable struct MockInvariant <: JuLS.Invariant
        nb_of_eval::Int
    end
    JuLS.InputType(::MockInvariant) = JuLS.SingleType()

    function JuLS.eval(i::MockInvariant, ::JuLS.SingleVariableMessage)
        return JuLS.FloatFullMessage(i.nb_of_eval)
    end

    invariant = MockInvariant(0.0)

    dag = JuLS.DAG(1)

    JuLS.add_invariant!(dag, invariant; variable_parent_indexes = [1])

    JuLS.init!(dag)

    test_path = joinpath(JuLS.PROJECT_ROOT, "dummy_folder_for_test3")

    input = JuLS.OutputInput(
        JuLS.DecisionVariablesArray([JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(1))]),
        JuLS.DecisionVariablesArray([JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(1))]),
        test_path,
    )

    JuLS.eval(dag, input)

    invariants_df = CSV.read(JuLS.invariant_filename(test_path), DataFrame)
    modified_invariants_df = CSV.read(JuLS.modified_invariant_filename(test_path), DataFrame)

    rm(test_path, recursive = true)

    @test names(invariants_df) == ["invariant_name", "old_value", "new_value"]
    @test names(modified_invariants_df) == ["invariant_name", "old_value", "new_value"]

    @test invariants_df.invariant_name == []
    @test modified_invariants_df.invariant_name == []

    @test invariants_df.old_value == []
    @test modified_invariants_df.old_value == []

    @test invariants_df.new_value == []
    @test modified_invariants_df.new_value == []
end

@testitem "Testing eval without a name but dif values" begin
    using CSV
    using DataFrames
    mutable struct MockInvariant <: JuLS.Invariant
        nb_of_eval::Int
    end
    JuLS.InputType(::MockInvariant) = JuLS.SingleType()

    function JuLS.eval(i::MockInvariant, ::JuLS.SingleVariableMessage)
        i.nb_of_eval += 1
        return JuLS.FloatFullMessage(i.nb_of_eval)
    end

    invariant = MockInvariant(0.0)

    dag = JuLS.DAG(1)

    JuLS.add_invariant!(dag, invariant; variable_parent_indexes = [1])

    JuLS.init!(dag)

    test_path = joinpath(JuLS.PROJECT_ROOT, "dummy_folder_for_test4")

    input = JuLS.OutputInput(
        JuLS.DecisionVariablesArray([JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(1))]),
        JuLS.DecisionVariablesArray([JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(1))]),
        test_path,
    )

    JuLS.eval(dag, input)

    invariants_df = CSV.read(JuLS.invariant_filename(test_path), DataFrame)
    modified_invariants_df = CSV.read(JuLS.modified_invariant_filename(test_path), DataFrame)

    rm(test_path, recursive = true)

    @test names(invariants_df) == ["invariant_name", "old_value", "new_value"]
    @test names(modified_invariants_df) == ["invariant_name", "old_value", "new_value"]

    @test invariants_df.invariant_name == []
    @test modified_invariants_df.invariant_name == []

    @test invariants_df.old_value == []
    @test modified_invariants_df.old_value == []

    @test invariants_df.new_value == []
    @test modified_invariants_df.new_value == []
end

@testitem "Testing eval with a name but no string output" begin
    using CSV
    using DataFrames
    mutable struct MockInvariant <: JuLS.Invariant
        nb_of_eval::Int
    end
    JuLS.InputType(::MockInvariant) = JuLS.SingleType()

    function JuLS.eval(i::MockInvariant, ::JuLS.SingleVariableMessage)
        i.nb_of_eval += 1
        return JuLS.FloatDelta(i.nb_of_eval)
    end

    invariant = MockInvariant(0.0)

    dag = JuLS.DAG(1)

    JuLS.add_invariant!(dag, invariant; variable_parent_indexes = [1])

    JuLS.init!(dag)

    test_path = joinpath(JuLS.PROJECT_ROOT, "dummy_folder_for_test5")

    input = JuLS.OutputInput(
        JuLS.DecisionVariablesArray([JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(1))]),
        JuLS.DecisionVariablesArray([JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(1))]),
        test_path,
    )

    JuLS.eval(dag, input)

    invariants_df = CSV.read(JuLS.invariant_filename(test_path), DataFrame)
    modified_invariants_df = CSV.read(JuLS.modified_invariant_filename(test_path), DataFrame)

    rm(test_path, recursive = true)

    @test names(invariants_df) == ["invariant_name", "old_value", "new_value"]
    @test names(modified_invariants_df) == ["invariant_name", "old_value", "new_value"]

    @test invariants_df.invariant_name == []
    @test modified_invariants_df.invariant_name == []

    @test invariants_df.old_value == []
    @test modified_invariants_df.old_value == []

    @test invariants_df.new_value == []
    @test modified_invariants_df.new_value == []
end

@testitem "_isbrokenconstraint" begin
    @test JuLS._isbrokenconstraint(JuLS.ComparatorInvariant(10), JuLS.FloatFullMessage(10.0))
    @test !JuLS._isbrokenconstraint(JuLS.ComparatorInvariant(10), JuLS.FloatFullMessage(0.0))
    @test !JuLS._isbrokenconstraint(JuLS.ElementInvariant(1, JuLS.IntDecisionValue[]), JuLS.FloatFullMessage(0.0))
    @test !JuLS._isbrokenconstraint(JuLS.ElementInvariant(1, JuLS.IntDecisionValue[]), JuLS.FloatFullMessage(10.0))
end
