# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    ClassicSampler <: VariableSampler

A classic random sampling strategy for selecting decision variables.

# Fields
- `_total_nb_of_variables::Int`: Total number of variables available for sampling

# Description
ClassicSampler implements a straightforward random sampling approach for selecting
variables. It ensures uniform random selection without replacement from the pool
of available variables.
"""
struct ClassicSampler <: VariableSampler
    _total_nb_of_variables::Int
end

_total_nb_of_variables(sampler::ClassicSampler) = sampler._total_nb_of_variables
is_initialized(sampler::ClassicSampler) = true

"""
    select_variables(
        ::Initialized,
        sampler::ClassicSampler,
        model::AbstractModel,
        number_of_variables_to_move::Int,
        rng::AbstractRNG,
        mask::BitVector
    )

Randomly samples a subset of variables from the model.

# Arguments
- `::Initialized`: Type parameter indicating the sampler is initialized
- `sampler::ClassicSampler`: The sampling strategy
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
    sampler::ClassicSampler,
    model::AbstractModel,
    number_of_variables_to_move::Int,
    rng::AbstractRNG,
    mask::BitVector,
)
    _is_valid(sampler, number_of_variables_to_move, mask)
    variable_ids = sample(rng, (1:_total_nb_of_variables(sampler))[mask], number_of_variables_to_move; replace = false)
    return decision_variables(model)[variable_ids]
end

@testitem "select_variables(::ClassicSampler)" begin
    using Random
    struct MockModel <: JuLS.AbstractModel end
    JuLS.decision_variables(::MockModel) =
        JuLS.DecisionVariable[JuLS.DecisionVariable(i, JuLS.IntDecisionValue(i)) for i = 1:10]
    sampler = JuLS.ClassicSampler(10)
    mask = trues(10)
    rng = Random.MersenneTwister(0)

    number_of_variables_to_move = 3

    variable_indexes = JuLS.select_variables(sampler, MockModel(), number_of_variables_to_move, rng, mask)

    @test length(variable_indexes) == 3
    @test length(variable_indexes) == length(Set(variable_indexes))
end

@testitem "classic sampler errors" begin
    using Random
    struct MockModel <: JuLS.AbstractModel end

    sampler = JuLS.ClassicSampler(3)

    rng = Random.MersenneTwister(0)

    @test_throws ErrorException("There are not enough variables!") JuLS.select_variables(
        sampler,
        MockModel(),
        6,
        rng,
        trues(3),
    )
    @test_throws ErrorException("It is impossible to sample from this origin mask.") JuLS.select_variables(
        sampler,
        MockModel(),
        2,
        rng,
        BitVector([0, 0, 1]),
    )
end