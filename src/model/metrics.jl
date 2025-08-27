# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    AbstractMetrics

Abstract type for metrics tracking optimization progress.
"""
abstract type AbstractMetrics end

"""
    RunMetrics <: AbstractMetrics

A structure to track and record metrics during the execution of an optimization algorithm.

# Fields
- `objective::Vector{Float64}` : Objective function values at each iteration
- `feasible::Vector{Bool}` : Solution feasibility indicators at each iteration
- `current_iteration::Int` : Current iteration number
- `initial_solution::Solution` : Initial solution of the algorithm
- `iteration_time::Vector{DateTime}` : Timestamp for each iteration
"""
mutable struct RunMetrics <: AbstractMetrics
    objective::Vector{Float64}
    feasible::Vector{Bool}
    current_iteration::Int
    initial_solution::Solution
    iteration_time::Vector{DateTime}
end

"""
    RunMetrics(initial_solution::Solution)

RunMetrics constructor that initializes metrics with an initial solution.
"""
function RunMetrics(initial_solution::Solution)
    run_metrics = RunMetrics([], [], 0, copy(initial_solution), [])

    # initialisation to record first solution
    increase_size!(run_metrics, 1)
    record_solution!(run_metrics, run_metrics.initial_solution)

    return run_metrics
end

"""
    resize_metrics!(m::RunMetrics, total_iterations::Int)

Function to resize the arrays that compose RunMetrics struct to the length specified by total_iterations.
"""
function resize_metrics!(m::RunMetrics, total_iterations::Int)
    if m.current_iteration > total_iterations
        return error("The size you gave is too small!")
    end
    resize!(m.objective, total_iterations)
    resize!(m.feasible, total_iterations)
    resize!(m.iteration_time, total_iterations)
end

"""
    increase_size!(m::RunMetrics, n_iterations::Int)

Increases the size of metrics vectors by n_iterations.
"""
increase_size!(m::RunMetrics, n_iterations::Int) = resize_metrics!(m, m.current_iteration + n_iterations)


function record_solution!(m::RunMetrics, current_solution::Solution)
    m.current_iteration += 1
    m.feasible[m.current_iteration] = current_solution.feasible
    m.objective[m.current_iteration] = current_solution.objective
    m.iteration_time[m.current_iteration] = now()
end

"""
    best_solution_indexes(m::RunMetrics)

Returns a vector of integers containing the indices of solutions that successively improved the best objective value among feasible solutions.
"""
function best_solution_indexes(m::RunMetrics)
    best_solutions = Int[]
    current_best_objective = typemax(Float64)

    for i = 1:m.current_iteration
        if !m.feasible[i]
            continue
        end

        if m.objective[i] < current_best_objective
            current_best_objective = m.objective[i]
            push!(best_solutions, i)
        end
    end

    return best_solutions
end

"""
    plot_objective(m::RunMetrics)

Creates a plot showing the evolution of the objective function and best solutions.
"""
function plot_objective(m::RunMetrics)
    best_solutions = JuLS.best_solution_indexes(m)

    p = plot(m.objective, label = "Objective")
    plot!(best_solutions, m.objective[best_solutions], seriestype = :scatter, label = "Best solutions")

    return p
end

@testitem "RunMetrics init" begin
    using Dates
    metrics = JuLS.RunMetrics(JuLS.Solution([], 10, false)) # We want the first solution to be stored in the metrics as if it was one iteration

    @test metrics.objective[1] == 10
    @test metrics.feasible[1] == false
    @test metrics.current_iteration == 1
    @test length(metrics.iteration_time) == 1
    @test (now() - metrics.iteration_time[1]).value > 0
end

@testitem "best_solution_indexes" begin
    metrics = JuLS.RunMetrics(JuLS.Solution([], 10, false))
    JuLS.resize_metrics!(metrics, 10)

    JuLS.record_solution!(metrics, JuLS.Solution([], 10, false))
    JuLS.record_solution!(metrics, JuLS.Solution([], 12, true))
    JuLS.record_solution!(metrics, JuLS.Solution([], 10, false))
    JuLS.record_solution!(metrics, JuLS.Solution([], 8, true))

    best_solutions = JuLS.best_solution_indexes(metrics)
    @test best_solutions == [3, 5]
end

@testitem "resize_runmetrics_length_eligible" begin
    metrics = JuLS.RunMetrics(JuLS.Solution([], 10, false))
    JuLS.resize_metrics!(metrics, 10)
    @test (length(metrics.objective) == 10) && (length(metrics.feasible) == 10)
end

@testitem "resize_runmetrics_length_non_eligible" begin
    metrics = JuLS.RunMetrics(JuLS.Solution([], 10, false))
    metrics.current_iteration = 12
    @test_throws ErrorException("The size you gave is too small!") JuLS.resize_metrics!(metrics, 10)
end

@testitem "record_solution" begin
    using Dates

    metrics = JuLS.RunMetrics(JuLS.Solution([], 10, false))
    JuLS.resize_metrics!(metrics, 10)
    @test metrics.objective[1] == 10
    @test metrics.feasible[1] == false
    @test metrics.current_iteration == 1
    @test length(metrics.iteration_time) == 10
    @test (now() - metrics.iteration_time[1]).value > 0

    JuLS.record_solution!(metrics, JuLS.Solution([], 10, true))

    @test metrics.objective[2] == 10
    @test metrics.feasible[2] == true
    @test metrics.current_iteration == 2
    @test (metrics.iteration_time[2] - metrics.iteration_time[1]).value > 0
end