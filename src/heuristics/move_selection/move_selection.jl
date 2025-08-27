# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

include("greedy.jl")
include("metropolis.jl")
include("simulated_annealing.jl")

"""
    pick_a_move(::MoveSelectionHeuristic, ::Vector{<:MoveEvaluatorOutput})

Choose a move among a set of already evaluated move using the heuristic given as the first argument.
"""
pick_a_move(::MoveSelectionHeuristic, ::Vector{<:MoveEvaluatorOutput}; rng = Random.GLOBAL_RNG) =
    error("Not implemented")