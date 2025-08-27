# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    OutputType

Abstract type representing different types of solution outputs in an optimization model.
"""
abstract type OutputType end

"""
    CurrentSolutionOutput <: OutputType

Represents output type to display the current solution state of the model.
"""
struct CurrentSolutionOutput <: OutputType end

"""
    BestSolutionOutput <: OutputType

Represents output type to display the best solution found during optimization.
"""
struct BestSolutionOutput <: OutputType end

Base.parse(::Type{OutputType}, str::AbstractString) = str == "LAST" ? CurrentSolutionOutput : BestSolutionOutput

"""
    OutputInput <: MoveEvaluatorInput

Structure containing information needed for generating output.

# Fields
- `best_variables::DecisionVariablesArray`: Decision variables state for the best (or current) solution found
- `original_variables::DecisionVariablesArray`: Decision variables state for the initial solution
- `path::String`: Output file path
"""
struct OutputInput <: MoveEvaluatorInput
    best_variables::DecisionVariablesArray
    original_variables::DecisionVariablesArray
    path::String
end

"""
    OutputInput(model::AbstractModel, path::String)
    OutputInput(::Type{OutputType}, model::AbstractModel, path::String)

Constructors for OutputInput with output type specification.

# Arguments
- `model::AbstractModel`: The optimization model
- `path::String`: Output file path
- `::Type{OutputType}`: Type of output (BestSolutionOutput or CurrentSolutionOutput)
"""
OutputInput(model::AbstractModel, path::String) = OutputInput(BestSolutionOutput, model, path)
OutputInput(::Type{BestSolutionOutput}, model::AbstractModel, path::String) = OutputInput(
    isnothing(model.best_solution) ? DecisionVariablesArray(model.run_metrics.initial_solution) :
    DecisionVariablesArray(model.best_solution),
    DecisionVariablesArray(model.run_metrics.initial_solution),
    path,
)
OutputInput(::Type{CurrentSolutionOutput}, model::AbstractModel, path::String) = OutputInput(
    DecisionVariablesArray(model.decision_variables),
    DecisionVariablesArray(model.run_metrics.initial_solution),
    path,
)
impacted_variables(oi::OutputInput) = impacted_variables(oi.original_variables)

"""
    make_output_folder(
        model::AbstractModel;
        output_path::String = joinpath(PROJECT_ROOT, "JuLS_output"),
        output_type::Type{<:OutputType} = BestSolutionOutput,
    )

Creates and populates an output folder with solution information in .csv files. 
Performs a validation check between final solution evaluation and incremental delta evaluation to verify the optimization consistency.

# Files Created
- variables.csv: All variable values
- modified_variables.csv: Only changed variables
- objective.csv: Objective function history
- broken_constraints.csv: Constraint violation information
"""
function make_output_folder(
    model::AbstractModel;
    output_path::String = joinpath(PROJECT_ROOT, "JuLS_output"),
    output_type::Type{<:OutputType} = BestSolutionOutput,
)
    if !(model.dag isa DAG)
        return
    end

    if ispath(output_path)
        rm(output_path; force = true, recursive = true)
    end
    mkpath(output_path)

    full_eval_solution = Solution(eval(model.dag, DecisionVariablesArray(model.decision_variables)))

    if (full_eval_solution.feasible != model.current_solution.feasible) ||
       !isapprox(full_eval_solution.objective, model.current_solution.objective)
        @error "FATAL ERROR, the full run drifted too much from the delta run"
        @error "Full eval solution: " full_eval_solution
        @error "Delta eval solution: " model.current_solution
        error()
    end

    @info "The full evaluation of current variables matches the delta evaluation, proceeding with output generation."

    _write_output(model, output_path; output_type)
end

"""
    _write_output(
        model::AbstractModel, 
        output_path::String; 
        output_type::Type{<:OutputType} = BestSolutionOutput
    )

Internal function to write solution data to files. This triggers a DAG full evaluation to write the output of each invariant.
"""
function _write_output(model::AbstractModel, output_path::String; output_type::Type{<:OutputType} = BestSolutionOutput)
    input = OutputInput(output_type, model, output_path)

    variables_df = DataFrame(
        id = 1:length(input.original_variables.variables),
        old_value = [v.current_value.value for v in input.original_variables.variables],
        new_value = [v.current_value.value for v in input.best_variables.variables],
    )
    objective_df = DataFrame(
        iteration = 1:length(model.run_metrics.objective),
        objective_value = model.run_metrics.objective,
        is_feasible = model.run_metrics.feasible,
        iteration_time = model.run_metrics.iteration_time,
    )
    broken_constraints_df = DataFrame(broken_constraints = [])

    CSV.write(joinpath(output_path, "variables.csv"), variables_df)
    CSV.write(joinpath(output_path, "objective.csv"), objective_df)
    CSV.write(joinpath(output_path, "broken_constraints.csv"), broken_constraints_df)

    filter!(row -> row.new_value != row.old_value, variables_df)

    CSV.write(joinpath(output_path, "modified_variables.csv"), variables_df)

    write_output_variables(
        helper(model.dag),
        [v.current_value for v in input.best_variables.variables],
        output_path::String,
    )

    eval(dag(model), input)
end

write_output_variables(::AbstractDAGHelper, ::Vector{<:DecisionValue}, ::String) = nothing

@testitem "Testing output for the knapsack" begin
    using Random
    using CSV
    using DataFrames
    experience = JuLS.KnapsackExperiment(JuLS.PROJECT_ROOT * "/data/knapsack/ks_4_0", 10.0)

    model =
        JuLS.init_model(experience; init = JuLS.SimpleInitialization(), neigh = JuLS.BinaryRandomNeighbourhood(50, 2))

    JuLS.optimize!(model; limit = JuLS.IterationLimit(1), rng = Random.MersenneTwister(0))

    test_path = joinpath(JuLS.PROJECT_ROOT, "dummy_folder_for_knapsack_test")

    JuLS.make_output_folder(model; output_path = test_path)

    invariants_df = CSV.read(JuLS.invariant_filename(test_path), DataFrame)
    modified_invariants_df = CSV.read(JuLS.modified_invariant_filename(test_path), DataFrame)

    variables_df = CSV.read(joinpath(test_path, "variables.csv"), DataFrame)
    modified_variables_df = CSV.read(joinpath(test_path, "modified_variables.csv"), DataFrame)

    objective_df = CSV.read(joinpath(test_path, "objective.csv"), DataFrame)

    rm(test_path, recursive = true)


    @test names(invariants_df) == ["invariant_name", "old_value", "new_value"]
    @test names(modified_invariants_df) == ["invariant_name", "old_value", "new_value"]

    @test invariants_df.invariant_name == ["constraint_violation", "objective_value"]
    @test invariants_df.old_value == [0.0, 0.0]
    @test invariants_df.new_value == [0.0, -19.0]

    @test modified_invariants_df.invariant_name == ["objective_value"]
    @test modified_invariants_df.old_value == [0.0]
    @test modified_invariants_df.new_value == [-19.0]

    @test names(variables_df) == ["id", "old_value", "new_value"]
    @test names(modified_variables_df) == ["id", "old_value", "new_value"]


    @test variables_df.id == [1, 2, 3, 4]
    @test variables_df.old_value == [false, false, false, false]
    @test variables_df.new_value == [false, false, true, true]

    @test modified_variables_df.id == [3, 4]
    @test modified_variables_df.old_value == [false, false]
    @test modified_variables_df.new_value == [true, true]

    @test names(objective_df) == ["iteration", "objective_value", "is_feasible", "iteration_time"]
    @test objective_df.iteration == [1, 2]
    @test objective_df.objective_value == [0.0, -19.0]
    @test objective_df.is_feasible == [true, true]
    @test length(objective_df.iteration_time) == 2
    @test (objective_df.iteration_time[1] - objective_df.iteration_time[2]).value < 0
end

@testitem "parse output type" begin
    @test parse(JuLS.OutputType, "LAST") == JuLS.CurrentSolutionOutput
    @test parse(JuLS.OutputType, "ANY") == JuLS.BestSolutionOutput
end


