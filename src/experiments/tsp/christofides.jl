# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    christofides(distances::Matrix{Float64})

Implements Christofides algorithm for solving the Traveling Salesman Problem (TSP).
Provides a 1.5-approximation for metric TSP instances.

# Arguments
- `distances::Matrix{Float64}`: Square matrix of distances between vertices

# Returns
Vector of vertex indices representing a Hamiltonian circuit

# Algorithm Steps
1. Compute minimum spanning tree (MST)
2. Find vertices with odd degree in MST
3. Compute minimum-weight perfect matching on odd-degree vertices
4. Combine MST with matching to get Eulerian graph
5. Find Eulerian circuit
6. Convert to Hamiltonian circuit by removing duplicates

# Notes
- Requires symmetric distance matrix satisfying triangle inequality
- Time complexity: O(n³) in worst case
"""
function christofides(distances::Matrix{<:Number})
    n = size(distances, 1)

    mst = prim_mst(distances)

    odd_vertices = findall(isodd, dropdims(sum(mst, dims = 2), dims = 2))

    # Find a perfect matching minimal for vertices with odd degree
    matching = minimum_weight_perfect_matching(distances[odd_vertices, odd_vertices])
    matching_adj = falses(n, n)
    for (i, j) in matching
        u, v = odd_vertices[i], odd_vertices[j]
        matching_adj[u, v] = true
        matching_adj[v, u] = true
    end

    combined = mst .| matching_adj

    eulerian_circuit = find_eulerian_circuit(combined)

    hamiltonian_circuit = unique(eulerian_circuit)

    return hamiltonian_circuit
end

"""
    prim_mst(distances::Matrix{Float64})

Computes Minimum Spanning Tree using Prim's algorithm.

# Arguments
- `distances::Matrix{Float64}`: Square matrix of edge weights

# Returns
BitMatrix representing the MST (true for edges in MST)

# Algorithm
1. Start with vertex 1
2. Repeatedly add minimum-weight edge connecting tree to unvisited vertex
3. Continue until all vertices are visited

# Complexity
O(n²) where n is number of vertices
"""
function prim_mst(distances::Matrix{<:Number})
    n = size(distances, 1)
    mst = zeros(Bool, n, n)
    visited = falses(n)
    visited[1] = true

    for _ = 1:n-1
        min_cost = Inf
        min_i, min_j = 0, 0
        for i = 1:n
            if visited[i]
                for j = 1:n
                    if !visited[j] && distances[i, j] < min_cost
                        min_cost = distances[i, j]
                        min_i, min_j = i, j
                    end
                end
            end
        end
        mst[min_i, min_j] = mst[min_j, min_i] = true
        visited[min_j] = true
    end

    return mst
end

"""
    minimum_weight_perfect_matching(distances::Matrix{Float64})

Finds minimum-weight perfect matching in a complete graph.

# Arguments
- `distances::Matrix{Float64}`: Square matrix of edge weights

# Returns
Vector of Tuple{Int,Int} representing matched pairs

# Algorithm
Greedy algorithm that repeatedly selects minimum-weight available edge.
Note: This is a simple approximation, not the optimal matching algorithm.

# Notes
For optimal solution, should use Edmonds' blossom algorithm
"""
function minimum_weight_perfect_matching(distances::Matrix{<:Number})
    n = size(distances, 1)
    matching = Tuple{Int,Int}[]
    unmatched = Set(1:n)

    while !isempty(unmatched)
        min_cost = Inf
        min_i, min_j = 0, 0
        for i in unmatched
            for j in unmatched
                if i != j && distances[i, j] < min_cost
                    min_cost = distances[i, j]
                    min_i, min_j = i, j
                end
            end
        end
        push!(matching, (min_i, min_j))
        delete!(unmatched, min_i)
        delete!(unmatched, min_j)
    end

    return matching
end

"""
    find_eulerian_circuit(adjacency::BitMatrix)

Finds Eulerian circuit in an undirected graph using Hierholzer's algorithm.

# Arguments
- `adjacency::BitMatrix`: Adjacency matrix of the graph

# Returns
Vector{Int} representing the Eulerian circuit

# Algorithm
1. Start from vertex 1
2. Follow unused edges, removing them as used
3. Backtrack when no unused edges remain
4. Final path gives Eulerian circuit

# Notes
- Assumes input graph is Eulerian (all vertices have even degree)
- Modifies input adjacency matrix
"""
function find_eulerian_circuit(adjacency::BitMatrix)
    circuit = Int[]
    stack = [1]

    while !isempty(stack)
        v = stack[end]
        neighbor = findfirst(adjacency[v, :])
        if isnothing(neighbor)
            push!(circuit, pop!(stack))
        else
            push!(stack, neighbor)
            adjacency[v, neighbor] = adjacency[neighbor, v] = false
        end
    end

    return circuit
end

@testitem "christofides()" begin
    distances = [
        0.0 2.0 9.0 10.0
        2.0 0.0 6.0 4.0
        9.0 6.0 0.0 3.0
        10.0 4.0 3.0 0.0
    ]

    node_sequence = JuLS.christofides(distances)
    @test node_sequence == [1, 3, 4, 2]

    tour_length =
        sum(distances[node_sequence[i], node_sequence[i+1]] for i = 1:length(node_sequence)-1) +
        distances[node_sequence[end], node_sequence[1]]
    @test tour_length == 18.0
end
