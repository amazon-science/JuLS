# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    (::SimpleInitialization)(e::TSPExperiment)

Simple initialization strategy for TSP that creates a trivial tour [1,2,...,n] (identity permutation)
"""
(::SimpleInitialization)(e::TSPExperiment) = collect(1:e.n_nodes)


"""
    (::GreedyInitialization)(e::TSPExperiment)

Greedy nearest neighbor initialization strategy for TSP.

# Arguments
- `e::TSPExperiment`: TSP experiment instance containing distance matrix

# Returns
Vector{Int} representing positions of each city in tour

# Algorithm
1. Start from city 1
2. Repeatedly:
   - Find nearest unvisited city
   - Add it to tour
   - Update current position
3. Continue until all cities are visited
"""
function (::GreedyInitialization)(e::TSPExperiment)
    n = e.n_nodes
    position = zeros(Int, n) .- 1
    position[1] = 1
    available = collect(2:n)
    current_node = 1
    for i = 2:n
        candidates = [e.distance_matrix[current_node, avail] for avail in available]
        min_candidate = argmin(candidates)
        current_node = available[min_candidate]
        deleteat!(available, min_candidate)
        position[current_node] = i
    end
    return position
end

struct ChristofidesInitialization <: InitializationHeuristic end

"""
    function (::ChristofidesInitialization)(e::TSPExperiment)

Initialization strategy using Christofides algorithm for metric TSP.
Provides a 1.5-approximation guarantee for metric instances.
"""
function (::ChristofidesInitialization)(e::TSPExperiment)
    node_sequence = christofides(e.distance_matrix)
    position = zeros(Int, e.n_nodes)
    for i = 1:e.n_nodes
        position[node_sequence[i]] = i
    end
    return position
end

@testitem "(::GreedyInitialization)(::TSPExperiment)" begin
    e = JuLS.TSPExperiment(JuLS.PROJECT_ROOT * "/data/tsp/tsp_5_1")
    greedy = JuLS.GreedyInitialization()
    positions = greedy(e)

    @test positions == [1, 2, 4, 5, 3]
end

@testitem "(::ChristofidesInitialization)(::TSPExperiment)" begin
    e = JuLS.TSPExperiment(JuLS.PROJECT_ROOT * "/data/tsp/tsp_5_1")
    h = JuLS.ChristofidesInitialization()
    positions = h(e)

    @test positions == [2, 1, 5, 4, 3]
end
