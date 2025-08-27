# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    VariableSampler

Abstract type defining the interface for variable sampling strategies in optimization.

# Purpose
Provides a framework for selecting variables during each iteration of optimization.
Different implementations can define various strategies for variable selection,
from simple random sampling to sophisticated guided selection.

# Interface Requirements
Concrete subtypes should implement:
- `select_variables(::Initialized, sampler, model, number_to_move, rng, mask)`
- `is_initialized(sampler)`
- `_total_nb_of_variables(sampler)`
"""
abstract type VariableSampler end

"""
    VariableSamplerInitStatus

Abstract type for representing initialization status of variable samplers.
Used to ensure proper initialization before sampling.
"""
abstract type VariableSamplerInitStatus end

struct Initialized <: VariableSamplerInitStatus end
struct NotInitialized <: VariableSamplerInitStatus end

InitStatus(sampler::VariableSampler) = is_initialized(sampler) ? Initialized() : NotInitialized()
is_initialized(sampler::VariableSampler) = sampler._is_init

"""
    select_variables(
        sampler::VariableSampler,
        m::AbstractModel,
        number_of_variables_to_move::Int,
        rng::AbstractRNG,
        mask::BitVector
    )

High-level interface for variable selection.

# Process
1. Checks initialization status
2. Initializes sampler if needed
3. Delegates to appropriate select_variables implementation

# Returns
Vector of selected variables
"""
select_variables(
    sampler::VariableSampler,
    m::AbstractModel,
    number_of_variables_to_move::Int,
    rng::AbstractRNG,
    mask::BitVector,
) = select_variables(InitStatus(sampler), sampler, m, number_of_variables_to_move, rng, mask)

"""
    select_variables(
        ::NotInitialized,
        sampler::VariableSampler,
        m::AbstractModel,
        number_of_variables_to_move::Int,
        rng::AbstractRNG,
        mask::BitVector
    )

Handles variable selection for uninitialized samplers.

# Process
1. Initializes the sampler
2. Forwards to regular select_variables implementation

# Notes
Called automatically when sampler needs initialization
"""
select_variables(
    ::NotInitialized,
    sampler::VariableSampler,
    m::AbstractModel,
    number_of_variables_to_move::Int,
    rng::AbstractRNG,
    mask::BitVector,
) = (init_sampler!(sampler, m); select_variables(sampler, m, number_of_variables_to_move, rng, mask))

"""
    _default_mask(::VariableSampler, model::AbstractModel)

Creates default mask allowing all variables to be selected.
"""
_default_mask(::VariableSampler, model::AbstractModel) = trues(_total_nb_of_variables(model))

"""
    _is_valid(total_number_of_variables::Int, 
              number_of_variables_to_move::Int, 
              mask::BitVector)

Validates variable selection parameters.

# Arguments
- `total_number_of_variables`: Total available variables
- `number_of_variables_to_move`: Number of variables to select
- `mask`: Availability mask

# Effects
Throws error if:
- Requested number exceeds total variables
- Mask doesn't allow enough variables to be selected

# Notes
Called before variable selection to ensure valid parameters
"""
function _is_valid(total_number_of_variables::Int, number_of_variables_to_move::Int, mask::BitVector)
    number_of_variables_to_move <= total_number_of_variables || error("There are not enough variables!")
    sum(mask) >= number_of_variables_to_move || error("It is impossible to sample from this origin mask.")
end
_is_valid(sampler::VariableSampler, number_of_variables_to_move::Int, mask::BitVector) =
    _is_valid(_total_nb_of_variables(sampler), number_of_variables_to_move, mask)


include("classic.jl")
include("combination_hints.jl")
include("tabu.jl")
include("weighted.jl")

