# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    CombinationHints <: VariableSampler

A variable sampler that uses predefined combinations to guide the sampling process.

# Fields
- `combination_set_matrix::BitMatrix`: Matrix defining interesting variable combinations

# Description
CombinationHints implements a sampling strategy that leverages predefined
combinations of variables. It aims to select variables that form meaningful
or interesting groups based on domain knowledge encoded in the combination matrix.
"""
struct CombinationHints <: VariableSampler
    combination_set_matrix::BitMatrix
end
_total_nb_of_variables(sampler::CombinationHints) = size(sampler.combination_set_matrix, 2)
is_initialized(sampler::CombinationHints) = true
function _is_valid(sampler::CombinationHints, number_of_variables_to_move::Int, mask::BitVector)
    _is_valid(_total_nb_of_variables(sampler), number_of_variables_to_move, mask)
    sum(any(sampler.combination_set_matrix, dims = 1) .& mask') >= number_of_variables_to_move || error(
        "These combination hints are not usable with this mask. Please consider using a hint combination_set_matrix that covers all your variables.",
    )
end

"""
    select_variables(
        ::Initialized,
        sampler::CombinationHints,
        model::AbstractModel,
        number_of_variables_to_move::Int,
        rng::AbstractRNG,
        mask::BitVector
    )

Selects variables using predefined combinations as guidance.

# Arguments
- `::Initialized`: Type parameter indicating the sampler is initialized
- `sampler::CombinationHints`: The sampling strategy
- `model::AbstractModel`: The optimization model
- `number_of_variables_to_move::Int`: Number of variables to select
- `rng::AbstractRNG`: Random number generator for sampling
- `mask::BitVector`: Mask specifying which variables are available for selection

# Returns
Vector of selected DecisionVariable instances

# Process
1. Validates input parameters
2. Randomly selects predefined combinations until enough variables are covered
3. Creates a combination mask based on selected combinations and input mask
4. Uses ClassicSampler to select final variables from the combination mask

# Notes
- Attempts to select variables that form interesting combinations
- May select more variables than requested in the combination step
- Final selection ensures exact number of variables is returned
- Respects the input mask for variable availability
"""
function select_variables(
    ::Initialized,
    sampler::CombinationHints,
    model::AbstractModel,
    number_of_variables_to_move::Int,
    rng::AbstractRNG,
    mask::BitVector,
)
    _is_valid(sampler, number_of_variables_to_move, mask)
    number_of_combinations = size(sampler.combination_set_matrix, 1)
    combination_mask = falses(_total_nb_of_variables(sampler))
    while sum(combination_mask) < number_of_variables_to_move
        combination_mask =
            combination_mask .| (sampler.combination_set_matrix[Random.rand(rng, 1:number_of_combinations), :] .& mask)
    end
    return select_variables(
        ClassicSampler(_total_nb_of_variables(sampler)),
        model,
        number_of_variables_to_move,
        rng,
        combination_mask,
    )
end



@testitem "select_variables(::CombinationHints)" begin
    using Random
    struct MockModel <: JuLS.AbstractModel end
    JuLS.decision_variables(::MockModel) =
        JuLS.DecisionVariable[JuLS.DecisionVariable(i, JuLS.IntDecisionValue(i)) for i = 1:4]

    matrix = BitMatrix([0 0 0 0; 1 0 1 0; 0 0 0 0])

    sampler = JuLS.CombinationHints(matrix)

    mask = trues(4)
    rng = Random.MersenneTwister(0)

    number_of_variables_to_move = 2

    @test Set([
        var.index for var in JuLS.select_variables(sampler, MockModel(), number_of_variables_to_move, rng, mask)
    ]) == Set([1, 3])
end

@testitem "select_variables(::CombinationHints) trying to select all possible values" begin
    using Random
    struct MockModel <: JuLS.AbstractModel end
    JuLS.decision_variables(::MockModel) =
        JuLS.DecisionVariable[JuLS.DecisionVariable(i, JuLS.IntDecisionValue(i)) for i = 1:4]

    combination_set_matrix = falses(2, 4)
    combination_set_matrix[1, 1] = 1
    combination_set_matrix[1, 2] = 1
    combination_set_matrix[1, 3] = 1
    combination_hints = JuLS.CombinationHints(combination_set_matrix)

    rng = Random.MersenneTwister(0)

    @test Set([var.index for var in JuLS.select_variables(combination_hints, MockModel(), 3, rng, trues(4))]) == Set([1, 2, 3])
end

@testitem "combination hints errors" begin
    using Random
    struct MockModel <: JuLS.AbstractModel end

    combination_set_matrix = falses(2, 5)
    combination_set_matrix[1, 1] = 1
    combination_set_matrix[1, 2] = 1
    combination_set_matrix[1, 3] = 1
    combination_hints = JuLS.CombinationHints(combination_set_matrix)

    rng = Random.MersenneTwister(0)

    @test_throws ErrorException("There are not enough variables!") JuLS.select_variables(
        combination_hints,
        MockModel(),
        6,
        rng,
        trues(5),
    )
    @test_throws ErrorException("It is impossible to sample from this origin mask.") JuLS.select_variables(
        combination_hints,
        MockModel(),
        2,
        rng,
        BitVector([0, 0, 0, 1, 0]),
    )
    @test_throws ErrorException(
        "These combination hints are not usable with this mask. Please consider using a hint combination_set_matrix that covers all your variables.",
    ) JuLS.select_variables(combination_hints, MockModel(), 2, rng, BitVector([0, 0, 0, 1, 1]))
end