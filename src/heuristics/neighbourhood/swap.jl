# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    SwapNeighbourhood <: NeighbourhoodHeuristic

A neighbourhood generation strategy that creates moves by swapping values between selected variables
through circular shifting.

# Fields
- `variable_sampler::VariableSampler`: Strategy for selecting variables to swap
- `number_of_variables_to_move::Int`: Number of variables involved in each swap (default: 2)
"""
struct SwapNeighbourhood <: NeighbourhoodHeuristic
    variable_sampler::VariableSampler
    number_of_variables_to_move::Int
end
SwapNeighbourhood(n_variables::Int, number_of_variables_to_move::Int = 2) =
    SwapNeighbourhood(ClassicSampler(n_variables), number_of_variables_to_move)
_default_mask(::SwapNeighbourhood, m::AbstractModel) = trues(length(decision_variables(m)))


function get_neighbourhood(
    h::SwapNeighbourhood,
    model::Model;
    rng = Random.GLOBAL_RNG,
    mask::BitVector = _default_mask(h, model),
)
    variable_sampled = select_variables(h.variable_sampler, model, h.number_of_variables_to_move, rng, mask)
    new_values = circshift([var.current_value for var in variable_sampled], 1)
    return [Move(variable_sampled, new_values)]
end