# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    AbstractModel

Abstract type representing an optimization model.
"""
abstract type AbstractModel end

"""
    NoMove <: MoveEvaluatorOutput

Represents a null move (no change to current state).
"""
struct NoMove <: MoveEvaluatorOutput end
const DONT_MOVE = NoMove()


"""
    DummyMoveFilter <: AbstractMoveFilter

Default move filter that performs no filtering.
"""
struct DummyMoveFilter <: AbstractMoveFilter end

const MOVE_BATCH_SIZE = 64

include("decision.jl")
include("output.jl")
include("solution.jl")
include("move.jl")
include("metrics.jl")
include("limit.jl")

"""
    Model <: AbstractModel

Main optimization model structure.

# Fields
- `decision_variables::Array{DecisionVariable}`: Decision variables being optimized
- `neighbourhood_heuristic::NeighbourhoodHeuristic`: Strategy for generating neighboring solutions
- `move_selection_heuristic::MoveSelectionHeuristic`: Strategy for selecting evaluated moves
- `dag::MoveEvaluator`: Directed Acyclic Graph for evaluating moves
- `current_solution::Solution`: Current state of the solution
- `best_solution::Union{Nothing,Solution}`: Best feasible solution found
- `run_metrics::AbstractMetrics`: Metrics tracking optimization progress
- `move_filter::AbstractMoveFilter`: Move filter to decrease the amount of move to evaluate
"""
mutable struct Model <: AbstractModel
    decision_variables::Array{DecisionVariable}
    neighbourhood_heuristic::NeighbourhoodHeuristic
    move_selection_heuristic::MoveSelectionHeuristic
    dag::MoveEvaluator
    current_solution::Solution
    best_solution::Union{Nothing,Solution}
    run_metrics::AbstractMetrics
    move_filter::AbstractMoveFilter
end

function Model(
    decision_variables::Array{DecisionVariable},
    neighbourhood_heuristic::NeighbourhoodHeuristic,
    move_selection_heuristic::MoveSelectionHeuristic,
    dag::MoveEvaluator;
    current_solution::Solution = Solution(decision_variables, dag),
    move_filter::AbstractMoveFilter = DummyMoveFilter(),
)
    best_solution = isfeasible(current_solution) ? copy(current_solution) : nothing
    return Model(
        decision_variables,
        neighbourhood_heuristic,
        move_selection_heuristic,
        dag,
        current_solution,
        best_solution,
        RunMetrics(current_solution),
        move_filter,
    )
end

Model(
    neighbourhood_heuristic::NeighbourhoodHeuristic,
    move_selection_heuristic::MoveSelectionHeuristic,
    dag::MoveEvaluator,
    current_solution::Solution,
) = Model(
    generate_decision_variables(current_solution),
    neighbourhood_heuristic,
    move_selection_heuristic,
    dag;
    current_solution,
)

generate_decision_variables(solution::Solution) = generate_decision_variables(values(solution))
generate_decision_variables(values::Vector{<:DecisionValue}) =
    DecisionVariable[DecisionVariable(i, values[i]) for i in eachindex(values)]

dag(model::AbstractModel) = model.dag
neighbourhood_heuristic(model::AbstractModel) = model.neighbourhood_heuristic
move_selection_heuristic(model::AbstractModel) = model.move_selection_heuristic
decision_variables(model::AbstractModel) = model.decision_variables
_total_nb_of_variables(model::AbstractModel) = length(decision_variables(model))
move_filter(::AbstractModel) = DummyMoveFilter()
move_filter(model::Model) = model.move_filter

after_move_hook!(::AbstractModel) = nothing
size_hint!(::AbstractModel, ::Int64) = nothing

"""
    apply_move!(model::Model, move::MoveEvaluatorOutput)

Applies an evaluated move to the model by updating the DAG invariant (through commit!), current solution, and decision variables.


# Notes
Changes are applied in sequence to maintain consistency across all model components.
"""
function apply_move!(model::Model, move::MoveEvaluatorOutput)
    commit!(model.dag, move)
    apply_move!(model.current_solution, move)
    apply_move!(model.decision_variables, move)
end
apply_move!(::Model, ::NoMove) = nothing

"""
    size_hint!(m::Model, n_iterations::Int)

Prepares the model's metrics storage for a specified number of iterations.
"""
function size_hint!(m::Model, n_iterations::Int)
    increase_size!(m.run_metrics, n_iterations)
end

"""
    after_move_hook!(model::Model)
Stores the current solution in model metrics and if is feasible and better than previous best solution.
Stores it as well in the model's best solution.
"""
function after_move_hook!(model::Model)
    record_solution!(model.run_metrics, model.current_solution)
    if !isfeasible(model.current_solution)
        return
    end

    if isnothing(model.best_solution) || model.current_solution.objective <= model.best_solution.objective
        model.best_solution = copy(model.current_solution)
    end
end

generate_input(::Type{Move}, ::AbstractModel, move::Move) = move

"""
    optimize!(model::AbstractModel; 
             rng = Random.GLOBAL_RNG, 
             n_iterations::Int = 100)

Main optimization function that iteratively improves the solution.

# Arguments
- `model::AbstractModel`: Model to optimize
- `rng`: Random number generator
- `n_iterations::Int`: Number of iterations to perform
"""
optimize!(model::AbstractModel; limit::Limit = IterationLimit(100), rng = Random.GLOBAL_RNG) =
    optimize!(model, Move, limit, rng)

function optimize!(
    model::AbstractModel,
    T::Type{<:MoveEvaluatorInput},
    iteration_limit::IterationLimit,
    rng = Random.GLOBAL_RNG,
)
    n_iterations = iteration_limit.n_iterations
    size_hint!(model, n_iterations)
    for _ = 1:n_iterations
        optimize_one_iteration!(model, T; rng)
    end
end

function optimize!(model::AbstractModel, T::Type{<:MoveEvaluatorInput}, time_limit::TimeLimit, rng = Random.GLOBAL_RNG)
    start!(time_limit)
    while !is_above(time_limit)
        size_hint!(model, 1)
        optimize_one_iteration!(model, T; rng)
    end
end

"""
    optimize_one_iteration!(model::AbstractModel, 
                          T::Type{<:MoveEvaluatorInput}; 
                          rng = Random.GLOBAL_RNG)

Performs one iteration of the optimization process.

# Steps
1. Generate neighborhood moves
2. Evaluate moves
3. Select and apply a move
4. Update metrics and best solution if necessary
"""
function optimize_one_iteration!(model::AbstractModel, T::Type{<:MoveEvaluatorInput}; rng = Random.GLOBAL_RNG)
    moves = get_neighbourhood(neighbourhood_heuristic(model), model; rng)

    evaluated_moves = evaluate_moves(model, T, moves)

    chosen_move = pick_a_move(move_selection_heuristic(model), evaluated_moves; rng)

    apply_move!(model, chosen_move)

    after_move_hook!(model) # Store best feasible solution here
end

"""
    evaluate_moves(model::AbstractModel,
                  T::Type{<:MoveEvaluatorInput},
                  moves::AbstractArray{<:MoveEvaluatorInput,1},
                  rng = Random.GLOBAL_RNG)

Performs a move filtering and a batched parallel evaluation on the set of moves. 

# Arguments
- `model`: Model being optimized
- `T`: Type of moves being evaluated
- `moves`: Array of potential moves
- `rng`: Random number generator
"""
function evaluate_moves(
    model::AbstractModel,
    T::Type{<:MoveEvaluatorInput},
    moves::AbstractArray{<:MoveEvaluatorInput,1},
    rng = Random.GLOBAL_RNG,
)
    filtered_moves = filter_moves(model, moves, rng)

    n_evaluation = length(filtered_moves)

    evaluated_moves = Vector{MoveEvaluatorOutput}(undef, n_evaluation)

    # We limit the number of parallel move evaluations to avoid an OutOfMemory error
    number_of_batches = n_evaluation ÷ MOVE_BATCH_SIZE + 1
    for i = 1:number_of_batches
        Threads.@threads for i = (1+(i-1)*MOVE_BATCH_SIZE):min(i * MOVE_BATCH_SIZE, n_evaluation)
            evaluated_moves[i] = MoveEvaluatorOutput(eval(dag(model), generate_input(T, model, filtered_moves[i])))
        end
    end

    return evaluated_moves
end

@testitem "Model init with solution" begin
    struct FakeNeighHeuristic <: JuLS.NeighbourhoodHeuristic end
    struct FakeMoveHeuristic <: JuLS.MoveSelectionHeuristic end
    struct FakeDAG <: JuLS.MoveEvaluator end

    # Unfeasible solution
    sol = JuLS.Solution([JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(4)], 2.3, false)
    model = JuLS.Model(FakeNeighHeuristic(), FakeMoveHeuristic(), FakeDAG(), sol)

    @test length(model.decision_variables) == 2
    @test model.decision_variables[1].index == 1
    @test JuLS.current_value(model.decision_variables[1]) == JuLS.IntDecisionValue(3)
    @test model.decision_variables[2].index == 2
    @test JuLS.current_value(model.decision_variables[2]) == JuLS.IntDecisionValue(4)
    @test model.current_solution == sol
    @test isnothing(model.best_solution)

    # Feasible solution
    sol = JuLS.Solution([JuLS.IntDecisionValue(5), JuLS.IntDecisionValue(6)], 2.3, true)
    model = JuLS.Model(FakeNeighHeuristic(), FakeMoveHeuristic(), FakeDAG(), sol)

    @test length(model.decision_variables) == 2
    @test model.decision_variables[1].index == 1
    @test JuLS.current_value(model.decision_variables[1]) == JuLS.IntDecisionValue(5)
    @test model.decision_variables[2].index == 2
    @test JuLS.current_value(model.decision_variables[2]) == JuLS.IntDecisionValue(6)
    @test model.current_solution == sol
    @test length(JuLS.values(model.best_solution)) == 2
    @test JuLS.isfeasible(model.best_solution)
    @test JuLS.values(model.best_solution)[1] == JuLS.IntDecisionValue(5)
    @test JuLS.values(model.best_solution)[2] == JuLS.IntDecisionValue(6)
end

@testitem "after_move_hook!()" begin
    struct FakeNeighHeuristic <: JuLS.NeighbourhoodHeuristic end
    struct FakeMoveHeuristic <: JuLS.MoveSelectionHeuristic end
    struct FakeDAG <: JuLS.MoveEvaluator end


    # No feasible solution stored, unfeasible solution given
    sol = JuLS.Solution([JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(4)], 2.3, false)
    model = JuLS.Model(FakeNeighHeuristic(), FakeMoveHeuristic(), FakeDAG(), sol)
    JuLS.increase_size!(model.run_metrics, 4)
    JuLS.after_move_hook!(model)
    @test isnothing(model.best_solution)

    # Feasible solution given
    model.current_solution = JuLS.Solution([JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(4)], 2.3, true)
    JuLS.after_move_hook!(model)
    @test !isnothing(model.best_solution)

    # Feasible but worse solution
    model.current_solution = JuLS.Solution([JuLS.IntDecisionValue(456), JuLS.IntDecisionValue(4)], 2.4, true)
    JuLS.after_move_hook!(model)
    @test JuLS.values(model.best_solution)[1] == JuLS.IntDecisionValue(3)

    # Feasible and as good of a solution (heuristic == replacing best solution when better was found)
    model.current_solution = JuLS.Solution([JuLS.IntDecisionValue(789), JuLS.IntDecisionValue(4)], 2.3, true)
    JuLS.after_move_hook!(model)
    @test JuLS.values(model.best_solution)[1] == JuLS.IntDecisionValue(789)
end

@testitem "apply_move!(::Model, ::NoMove)" begin
    experience = JuLS.KnapsackExperiment(JuLS.PROJECT_ROOT * "/data/knapsack/ks_4_0", 10.0)
    model = JuLS.init_model(experience)

    decision_variables = copy(model.decision_variables)

    JuLS.apply_move!(model, JuLS.NoMove())

    @test model.decision_variables == decision_variables
end
