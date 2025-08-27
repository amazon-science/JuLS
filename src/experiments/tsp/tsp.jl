# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    TSPExperiment <: Experiment

Represents a Traveling Salesman Problem (TSP) experiment instance.

# Fields
- `input_file::String`: Path to file containing city coordinates
- `n_nodes::Int`: Number of cities
- `distance_matrix::Matrix{Float64}`: Matrix of pairwise distances between cities. The distance is L2 rounded to the closest integer.

# File Format
Expected input file format:

n_nodes
x1 y1
x2 y2
...
xn yn

Where (xi,yi) are coordinates of city i.
"""
struct TSPExperiment <: Experiment
    input_file::String
    n_nodes::Int
    distance_matrix::Matrix{Int}
    α::Float64

    TSPExperiment(input_file::String, α::Float64 = DEFAULT_PENALTY_PARAM) =
        open(input_file, "r") do f
            lines = readlines(f)[2:end]
            n = length(lines)
            coordinates = Array{Float64}(undef, (n, 2))
            for i = 1:n
                coordinates[i, :] = parse.(Float64, split(lines[i]))
            end
            return new(input_file, n, generate_distances(coordinates), α)
        end
end
"""
    n_decision_variables(e::TSPExperiment)
    
One decision variable per city.
"""
n_decision_variables(e::TSPExperiment) = e.n_nodes

"""
    decision_type(::TSPExperiment)

The value of a decision determines the position of the corresponding city in the tour (from 1 to n)
"""
decision_type(::TSPExperiment) = IntDecisionValue
generate_domains(e::TSPExperiment) = [collect(1:e.n_nodes) for _ = 1:e.n_nodes]

function generate_distances(coord::Array{Float64})
    n = size(coord)[1]
    dist_matrix = zeros(Int, n, n)
    for i in range(1, n)

        for j in range(i + 1, n)
            dist_matrix[i, j] = L2(coord[i, :], coord[j, :])
            dist_matrix[j, i] = dist_matrix[i, j]
        end
    end
    return dist_matrix
end
L2(coord1::Vector{Float64}, coord2::Vector{Float64}) =
    Int(round(sqrt((coord1[1] - coord2[1])^2 + (coord1[2] - coord2[2])^2)))

include("christofides.jl")
include("tsp_init.jl")
include("tsp_dag.jl")

default_init(::TSPExperiment) = ChristofidesInitialization()
default_neigh(::TSPExperiment) = KOptNeighbourhood(1, 2)
default_pick(::TSPExperiment) = GreedyMoveSelection()
default_using_cp(::TSPExperiment) = false
create_dag(e::TSPExperiment) = create_tsp_dag(e.distance_matrix, e.α)

@testitem "TSPExperiment initialization" begin
    e = JuLS.TSPExperiment(JuLS.PROJECT_ROOT * "/data/tsp/tsp_5_1")

    @test e.input_file == JuLS.PROJECT_ROOT * "/data/tsp/tsp_5_1"
    @test e.distance_matrix == [0 0 2 3 1; 0 0 2 3 1; 2 2 0 3 2; 3 3 3 0 2; 1 1 2 2 0]
    @test e.n_nodes == 5
end

@testitem "init_model(::TSPExperiment)" begin
    e = JuLS.TSPExperiment(JuLS.PROJECT_ROOT * "/data/tsp/tsp_5_1")
    model = JuLS.init_model(e)

end
