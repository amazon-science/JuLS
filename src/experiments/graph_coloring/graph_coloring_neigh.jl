# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    GraphVariableSampler <: VariableSampler

A variable sampler for graph-based problems that selects connected or nearby nodes.

# Fields
- `adjacency_matrix::BitMatrix`: Binary adjacency matrix representing the graph structure

# Description
The GraphVariableSampler implements a neighborhood-based sampling strategy for graph coloring
problems. It selects variables (nodes) that are connected or close to each other in the graph,
promoting more effective local search moves.

# Sampling Strategy
1. Randomly selects a starting node from available nodes (masked)
2. Iteratively adds nodes by:
   - Preferentially selecting from unvisited neighbors of already selected nodes
   - If no neighbors available, randomly selects from remaining unvisited nodes
3. Continues until reaching desired number of variables
"""
struct GraphVariableSampler <: VariableSampler
    adjacency_matrix::BitMatrix
end
GraphVariableSampler(e::GraphColoringExperiment) = GraphVariableSampler(e.adjacency_matrix)

_total_nb_of_variables(sampler::GraphVariableSampler) = size(sampler.adjacency_matrix, 1)
is_initialized(sampler::GraphVariableSampler) = true

function select_variables(
    ::Initialized,
    sampler::GraphVariableSampler,
    model::AbstractModel,
    number_of_variables_to_move::Int,
    rng::AbstractRNG,
    mask::BitVector,
)
    _is_valid(sampler, number_of_variables_to_move, mask)

    start_node = rand(rng, findall(mask))
    selected_nodes = [start_node]

    unvisited_nodes = copy(mask)
    unvisited_nodes[start_node] = false
    unvisited_neigh_nodes = unvisited_nodes .& sampler.adjacency_matrix[start_node, :]

    while length(selected_nodes) < number_of_variables_to_move
        neigh_nodes = findall(unvisited_neigh_nodes)
        new_node = isempty(neigh_nodes) ? rand(rng, findall(unvisited_nodes)) : rand(rng, neigh_nodes)
        push!(selected_nodes, new_node)
        unvisited_nodes[new_node] = false
        unvisited_neigh_nodes[new_node] = false
        unvisited_neigh_nodes .|= unvisited_nodes .& sampler.adjacency_matrix[new_node, :]
    end

    return decision_variables(model)[selected_nodes]
end

coloring_neighbourhood(e::GraphColoringExperiment, complexity::Int = 2) =
    ExhaustiveNeighbourhood(complexity, GraphVariableSampler(e))


@testitem "select_variables(::GraphVariableSampler)" begin
    using Random
    rng = MersenneTwister(0)

    e = JuLS.GraphColoringExperiment(JuLS.PROJECT_ROOT * "/data/graph_coloring/gc_20_1", 10)
    model = JuLS.init_model(e)
    sampler = JuLS.GraphVariableSampler(e)

    nodes = [var.index for var in JuLS.select_variables(sampler, model, 3, rng, trues(20))]
    @test nodes == [3, 17, 12]

    nodes = [var.index for var in JuLS.select_variables(sampler, model, 8, rng, trues(20))]
    @test nodes == [1, 17, 4, 3, 20, 15, 12, 2]

    nodes = [var.index for var in JuLS.select_variables(sampler, model, 18, rng, trues(20))]
    @test nodes == [15, 4, 17, 3, 12, 18, 5, 6, 1, 20, 16, 7, 2, 9, 8, 19, 14, 11]
end