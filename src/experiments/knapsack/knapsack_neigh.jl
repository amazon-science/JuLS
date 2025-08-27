# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    KnapsackSampler <: VariableSampler

A specialized variable sampler for the Knapsack Problem that maintains balance between 
selected and unselected items.

# Fields
- `n_items::Int`: Total number of items in the knapsack problem

# Description
This sampler implements a balanced sampling strategy where:
- Approximately half of the sampled variables come from currently selected items
- The remaining samples come from unselected items
This approach helps maintain diversity in the search while exploring both inclusion 
and exclusion of items.
"""
struct KnapsackSampler <: VariableSampler
    n_items::Int
end

_total_nb_of_variables(sampler::KnapsackSampler) = length(sampler.n_items)
is_initialized(sampler::KnapsackSampler) = true

function select_variables(
    ::Initialized,
    sampler::KnapsackSampler,
    model::AbstractModel,
    number_of_variables_to_move::Int,
    rng::AbstractRNG,
    ::BitVector,
)

    sol = BitVector([val.value for val in model.current_solution.values])
    active_items = findall(sol)
    inactive_items = findall(.!sol)

    n_sample_active = min(length(active_items), number_of_variables_to_move ÷ 2)
    n_sample_inactive = min(length(inactive_items), number_of_variables_to_move - n_sample_active)

    indexes = vcat(
        sample(rng, active_items, n_sample_active, replace = false),
        sample(rng, inactive_items, n_sample_inactive, replace = false),
    )

    return decision_variables(model)[indexes]
end

