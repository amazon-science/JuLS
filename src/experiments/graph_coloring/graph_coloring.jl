# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    GraphColoringExperiment <: Experiment

Represents a Graph Coloring Problem experiment instance.

# Fields
- `input_file::String`: Path to file containing problem data
- `max_color::Int`: Maximum number of color for this problem
- `α::Float64`: Penalty parameter for constraint violation
- `n_nodes::Int`: Number of nodes
- `n_edges::Int`: Number of edges
- `greedy_coloring::Vector{Int}`: Coloration with greedy algorithm
- `edges::Vector{Tuple{Int,Int}}`: List of edges

# File Format
Expected input file format:

n_nodes n_edges
node_1_1 node_1_2 (edge 1)
node_2_1 node_2_2 (edge 2)
...
node_n_1 node_n_2 (edge n)
"""
struct GraphColoringExperiment <: Experiment
    input_file::String
    max_color::Int
    α::Float64
    n_nodes::Int
    edges::Vector{Tuple{Int,Int}}
    adjacency_matrix::BitMatrix

    GraphColoringExperiment(input_file::String, max_color::Int, α::Float64 = DEFAULT_PENALTY_PARAM) =
        open(input_file, "r") do f
            lines = readlines(f)
            n_nodes, n_edges = parse.(Int, split(lines[1]))
            edges = Tuple{Int,Int}[]
            adjacency_matrix = falses(n_nodes, n_nodes)
            for i = 1:n_edges
                node1, node2 = parse.(Int, split(lines[i+1]))
                push!(edges, Tuple([node1, node2]))
                adjacency_matrix[node1, node2] = true
                adjacency_matrix[node2, node1] = true
            end
            return new(input_file, max_color, α, n_nodes, edges, adjacency_matrix)
        end
end

"""
    n_decision_variables(e::GraphColoringExperiment)

The number of decision variables is equal to number of nodes.
"""
n_decision_variables(e::GraphColoringExperiment) = e.n_nodes

"""
    decision_type(::GraphColoringExperiment)

Decision is the color selected for each node (indexed by Int)
"""
decision_type(::GraphColoringExperiment) = IntDecisionValue
generate_domains(e::GraphColoringExperiment) = [collect(1:e.max_color) for _ = 1:e.n_nodes]

include("graph_coloring_init.jl")
include("graph_coloring_dag.jl")
include("graph_coloring_neigh.jl")

default_init(::GraphColoringExperiment) = GreedyInitialization()
default_neigh(e::GraphColoringExperiment) = coloring_neighbourhood(e, 3)
default_pick(::GraphColoringExperiment) = GreedyMoveSelection()
default_using_cp(::GraphColoringExperiment) = true
create_dag(e::GraphColoringExperiment) = create_graph_coloring_dag(e.n_nodes, e.edges, e.max_color, e.α)

@testitem "init_model(::GraphColoringExperiment)" begin
    e = JuLS.GraphColoringExperiment(JuLS.PROJECT_ROOT * "/data/graph_coloring/gc_4_1", 4)
    model = JuLS.init_model(e; init = JuLS.SimpleInitialization())
    JuLS.optimize!(model; limit = JuLS.IterationLimit(1))

    @test model.current_solution.objective < model.run_metrics.objective[1]
end