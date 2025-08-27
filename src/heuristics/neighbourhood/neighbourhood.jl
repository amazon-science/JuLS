# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

const NO_MOVE = Move(DecisionVariable[], DecisionValue[])

include("variable_sampler/variable_sampler.jl")
include("binary_single.jl")
include("binary_random.jl")
include("exhaustive.jl")
include("k_opt.jl")
include("greedy.jl")
include("random.jl")
include("swap.jl")

"""
    get_neighbour(::NeighbourhoodHeuristic, ::AbstractModel)

Return an array of potential moves that can be done from the current solution.
"""
get_neighbourhood(::NeighbourhoodHeuristic, ::AbstractModel; rng = Random.GLOBAL_RNG) = error("Not implemented")
get_neighbourhood(m::AbstractModel; rng = Random.GLOBAL_RNG) = get_neighbourhood(neighbourhood_heuristic(m), m; rng)

"""
Update the internal state of the neighbourhood heuristic.
"""
update!(::NeighbourhoodHeuristic, ::AbstractMetrics) = nothing