# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    WeightedSampler <: VariableSampler

A classic random sampling strategy for selecting decision variables.

# Fields
- `_total_nb_of_variables::Int`: Total number of variables available for sampling

# Description
WeightedSampler implements a straightforward random sampling approach for selecting
variables. It ensures uniform random selection without replacement from the pool
of available variables.
"""
struct WeightedSampler <: VariableSampler
    weights::Vector{Float64}
end

_total_nb_of_variables(sampler::WeightedSampler) = length(sampler.weights)
is_initialized(sampler::WeightedSampler) = true

"""
    select_variables(
        ::Initialized,
        sampler::WeightedSampler,
        model::AbstractModel,
        number_of_variables_to_move::Int,
        rng::AbstractRNG,
        mask::BitVector
    )

Randomly samples a subset of variables from the model.

# Arguments
- `::Initialized`: Type parameter indicating the sampler is initialized
- `sampler::WeightedSampler`: The sampling strategy
- `model::AbstractModel`: The optimization model
- `number_of_variables_to_move::Int`: Number of variables to select
- `rng::AbstractRNG`: Random number generator for sampling
- `mask::BitVector`: Mask specifying which variables are available for selection

# Returns
Vector of selected DecisionVariable instances

# Process
1. Validates input parameters
2. Samples variable IDs based on the mask
3. Retrieves corresponding DecisionVariable instances from the model

# Notes
- Sampling is done without replacement
- The mask allows for restricting the pool of variables available for selection
- Throws an error if the requested number of variables exceeds available variables
"""
function select_variables(
    ::Initialized,
    sampler::WeightedSampler,
    model::AbstractModel,
    number_of_variables_to_move::Int,
    rng::AbstractRNG,
    mask::BitVector,
)
    _is_valid(sampler, number_of_variables_to_move, mask)
    variable_ids = sample(
        rng,
        (1:_total_nb_of_variables(sampler))[mask],
        Weights(sampler.weights[mask]),
        number_of_variables_to_move;
        replace = false,
    )
    return decision_variables(model)[variable_ids]
end

@testitem "select_variables(::WeightedSampler)" begin
    using Random
    struct MockModel <: JuLS.AbstractModel end
    JuLS.decision_variables(::MockModel) =
        JuLS.DecisionVariable[JuLS.DecisionVariable(i, JuLS.IntDecisionValue(i)) for i = 1:10]
    sampler = JuLS.WeightedSampler([0.3, 0.2, 0.1, 0.3, 0.2, 0.1, 0.0, 0.0, 0.0, 0.0])
    mask = trues(10)
    rng = Random.MersenneTwister(0)

    number_of_variables_to_move = 3

    variables = JuLS.select_variables(sampler, MockModel(), number_of_variables_to_move, rng, mask)
    indexes = [var.index for var in variables]

    @test length(variables) == 3
    @test indexes == [6, 2, 3]
end