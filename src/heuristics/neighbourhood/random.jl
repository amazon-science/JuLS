# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    RandomNeighbourhood <: NeighbourhoodHeuristic

A neighbourhood generation strategy that randomly samples variables and assigns them random values
from their domains.

# Fields
- `variable_sampler::VariableSampler`: Strategy for selecting variables
- `number_of_variables_to_move::Int`: Number of variables to modify in each move
"""
struct RandomNeighbourhood <: NeighbourhoodHeuristic
    variable_sampler::VariableSampler
    number_of_variables_to_move::Int
end
RandomNeighbourhood(n_variables::Int, number_of_variables_to_move::Int=1) =
    RandomNeighbourhood(ClassicSampler(n_variables), number_of_variables_to_move)
_default_mask(::RandomNeighbourhood, m::AbstractModel) = trues(length(decision_variables(m)))

function get_neighbourhood(
    h::RandomNeighbourhood,
    model::Model;
    rng=Random.GLOBAL_RNG,
    mask::BitVector=_default_mask(h, model),
)
    sampled_variables = select_variables(h.variable_sampler, model, h.number_of_variables_to_move, rng, mask)
    new_decision_values = [sample(rng, var.domain, 1)[1] for var in sampled_variables]
    return vcat(NO_MOVE, [Move(sampled_variables, new_decision_values)])
end

