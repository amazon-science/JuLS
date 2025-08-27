# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct AdjacencyMatrix

Represent an adjacency matrix. Sepcifically used for the DAG in this case. 
We need to have knowledge both ways about children and parents.
Because it is specifically used for the DAG, neighbours are represented through a Vector{Vector{Int}}
indexed by invariant ID.

This struct is meant to be used only internally by the DAG.

# Fields
- `_children_adjacency_matrix::Vector{Vector{Int}}`: The children neighbours of invariants. 
- `_parent_adjacency_matrix::Vector{Vector{Int}}`: The parents neighbours of invariants. 
"""
struct AdjacencyMatrix
    _children_adjacency_matrix::Vector{Vector{Int}}
    _parent_adjacency_matrix::Vector{Vector{Int}}
end
AdjacencyMatrix() = AdjacencyMatrix([], [])

"""
    add_node!(::AdjacencyMatrix)

Add a node to the adjacency matrix. 
The underlying action is to add a node to both the children and parent adjacency matrix.

# Arguments
- `adj_matrix::AdjacencyMatrix`: The adjacency matrix. 
"""
function add_node!(adj_matrix::AdjacencyMatrix)
    push!(adj_matrix._children_adjacency_matrix, [])
    push!(adj_matrix._parent_adjacency_matrix, [])

    return length(adj_matrix._children_adjacency_matrix)
end

"""
    add_edge!(::AdjacencyMatrix, ::Int, ::Int)

Add an edge between two nodes to the adjacency matrix. 
The underlying action is to add a directed edge to both the children and parent adjacency matrix.

# Arguments
- `adj_matrix::AdjacencyMatrix`: The adjacency matrix. 
- `index_origin::Int`: Origin index of the edge. 
- `index_destination::Int`: Destination index of the edge. 
"""
function add_edge!(adj_matrix::AdjacencyMatrix, index_origin::Int, index_destination::Int)
    push!(adj_matrix._children_adjacency_matrix[index_origin], index_destination)
    push!(adj_matrix._parent_adjacency_matrix[index_destination], index_origin)
end

"""
    children(::AdjacencyMatrix, ::Int)

Get the children of a given invariant.

# Arguments
- `adj_matrix::AdjacencyMatrix`: The adjacency matrix. 
- `index::Int`: Index of the invariant. 
"""
children(adj_matrix::AdjacencyMatrix, index::Int) = adj_matrix._children_adjacency_matrix[index]

"""
    parents(::AdjacencyMatrix, ::Int)

Get the parents of a given invariant.

# Arguments
- `adj_matrix::AdjacencyMatrix`: The adjacency matrix. 
- `index::Int`: Index of the invariant. 
"""
parents(adj_matrix::AdjacencyMatrix, index::Int) = adj_matrix._parent_adjacency_matrix[index]

"""
    children_degrees(::AdjacencyMatrix)

Get the vector of children degrees of the adjacency matrix.

# Arguments
- `adj_matrix::AdjacencyMatrix`: The adjacency matrix. 
"""
children_degrees(adj_matrix::AdjacencyMatrix) =
    [length(adj_matrix._children_adjacency_matrix[index]) for index = 1:length(adj_matrix._children_adjacency_matrix)]

"""
    parents_degrees(::AdjacencyMatrix)

Get the vector of parents degrees of the adjacency matrix.

# Arguments
- `adj_matrix::AdjacencyMatrix`: The adjacency matrix. 
"""
parents_degrees(adj_matrix::AdjacencyMatrix) =
    [length(adj_matrix._parent_adjacency_matrix[index]) for index = 1:length(adj_matrix._parent_adjacency_matrix)]

@testitem "Testing adjacency matrix constructor" begin
    adj_matrix = JuLS.AdjacencyMatrix()

    @test adj_matrix._children_adjacency_matrix == []
    @test adj_matrix._parent_adjacency_matrix == []
end

@testitem "Testing add_node" begin
    adj_matrix = JuLS.AdjacencyMatrix()

    node_index = JuLS.add_node!(adj_matrix)

    @test node_index == 1

    @test adj_matrix._parent_adjacency_matrix == [[]]
    @test adj_matrix._children_adjacency_matrix == [[]]

    node_index = JuLS.add_node!(adj_matrix)

    @test node_index == 2

    @test adj_matrix._parent_adjacency_matrix == [[], []]
    @test adj_matrix._children_adjacency_matrix == [[], []]
end

@testitem "Testing add_edge" begin
    adj_matrix = JuLS.AdjacencyMatrix()

    JuLS.add_node!(adj_matrix)
    JuLS.add_node!(adj_matrix)

    JuLS.add_edge!(adj_matrix, 1, 2)

    @test adj_matrix._parent_adjacency_matrix == [[], [1]]
    @test adj_matrix._children_adjacency_matrix == [[2], []]
end

@testitem "Testing children and parents" begin
    adj_matrix = JuLS.AdjacencyMatrix()

    JuLS.add_node!(adj_matrix)
    JuLS.add_node!(adj_matrix)

    JuLS.add_edge!(adj_matrix, 1, 2)

    @test JuLS.parents(adj_matrix, 1) == []
    @test JuLS.parents(adj_matrix, 2) == [1]
    @test JuLS.children(adj_matrix, 1) == [2]
    @test JuLS.children(adj_matrix, 2) == []
end

@testitem "Testing children and parents degrees" begin
    adj_matrix = JuLS.AdjacencyMatrix()

    JuLS.add_node!(adj_matrix)
    JuLS.add_node!(adj_matrix)

    JuLS.add_edge!(adj_matrix, 1, 2)

    @test JuLS.children_degrees(adj_matrix) == [1, 0]
    @test JuLS.parents_degrees(adj_matrix) == [0, 1]
end