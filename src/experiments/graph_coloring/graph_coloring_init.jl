# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    (::SimpleInitialization)(e::GraphColoringExperiment)

Simple initialization strategy for Graph Coloring Problem that sets all nodes at color 1
"""
(::SimpleInitialization)(e::GraphColoringExperiment) = fill(1, e.n_nodes)

"""
    (::GreedyInitialization)(e::GraphColoringExperiment)

Greedy initialization strategy for Graph Coloring Problem.

# Algorithm
1. Sort vertices by degree in descending order
2. Assign the first available color to each vertex, if no availability, pick the one with minimum conflict
3. Return the color assignment
"""
function (::GreedyInitialization)(e::GraphColoringExperiment)
    degrees = sum(e.adjacency_matrix, dims = 2)[:]
    sorted_vertices = sortperm(degrees, rev = true)

    colors = zeros(Int, e.n_nodes)
    for v in sorted_vertices
        color_counter = zeros(Int, e.max_color)
        for u = 1:e.n_nodes
            if e.adjacency_matrix[v, u] == 1 && colors[u] != 0
                color_counter[colors[u]] += 1
            end
        end
        color = findfirst(c -> iszero(c), color_counter)
        if isnothing(color)
            color = argmin(color_counter)
        end
        colors[v] = color
    end
    return colors
end

@testitem "(::GreedyInitialization)(::GraphColoringExperiment)" begin
    e = JuLS.GraphColoringExperiment(JuLS.PROJECT_ROOT * "/data/graph_coloring/gc_4_1", 2)
    greedy = JuLS.GreedyInitialization()
    @test greedy(e) == [2, 1, 2, 2]
end