# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

module JuLS

using TestItems
using Dates
using StatsBase
using DataFrames
using CSV
using DataStructures
using Random
using Combinatorics


const PROJECT_ROOT = pkgdir(JuLS)

# Definition of abstract types. Required to be defined here to avoid compilation
# errors due to dependencies
abstract type NeighbourhoodHeuristic end
abstract type MoveSelectionHeuristic end
abstract type InitializationHeuristic end
abstract type AbstractMoveFilter end
abstract type DAGMessage end
abstract type Delta <: DAGMessage end
abstract type FullMessage <: DAGMessage end
abstract type MoveEvaluator end
abstract type MoveEvaluatorInput <: DAGMessage end
abstract type MoveEvaluatorOutput end
abstract type Invariant end
abstract type AbstractDAGHelper end

include("model/model.jl")
include("dag/dag.jl")
include("cp/cp.jl")
include("heuristics/heuristics.jl")
include("experiments/experiments.jl")

export
    Model,
    init_model,

    # Experiment
    KnapsackExperiment,
    TSPExperiment,
    GraphColoringExperiment,

    # InitializationHeuristic
    SimpleInitialization,
    GreedyInitialization,
    ChristofidesInitialization,

    # NeighbourhoodHeuristic
    BinaryRandomNeighbourhood,
    BinarySingleNeighbourhood,
    ExhaustiveNeighbourhood,
    GreedyNeighbourhood,
    KOptNeighbourhood,
    RandomNeighbourhood,
    SwapNeighbourhood,

    # MoveSelectionHeuristic
    GreedyMoveSelection,
    Metropolis,
    SimulatedAnnealing,

    # Optimization
    optimize!,
    IterationLimit,
    TimeLimit,

    # DAG and Decision values
    DAG,
    DecisionValue,
    IntDecisionValue,

    # Custom experiments
    Experiment,
    n_decision_variables,
    decision_type,
    generate_domains,
    create_dag
end