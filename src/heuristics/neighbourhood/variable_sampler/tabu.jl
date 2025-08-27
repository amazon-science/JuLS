# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    TabuSampler <: VariableSampler

A variable sampler that implements tabu search principles by temporarily prohibiting
recently selected variables.

# Fields
- `current_iteration::Int`: Current iteration counter
- `waiting_time::Int`: Number of iterations a variable remains tabu after selection
- `minimal_iteration_number::Vector{Int}`: Earliest iteration when each variable becomes available again
- `subsampler::VariableSampler`: Base sampler used when selecting from non-tabu variables

# Description
TabuSampler implements a sampling strategy that maintains a tabu list of recently
selected variables. This helps prevent cycling and promotes exploration of different
variable combinations.
"""
mutable struct TabuSampler <: VariableSampler
    current_iteration::Int
    waiting_time::Int
    minimal_iteration_number::Vector{Int}
    subsampler::VariableSampler
end
TabuSampler(waiting_time::Int, subsampler::VariableSampler) =
    TabuSampler(1, waiting_time, zeros(Int, _total_nb_of_variables(subsampler)), subsampler)
TabuSampler(waiting_time::Int, total_number_of_variables::Int) =
    TabuSampler(1, waiting_time, zeros(Int, total_number_of_variables), ClassicSampler(total_number_of_variables))

_total_nb_of_variables(sampler::TabuSampler) = _total_nb_of_variables(sampler.subsampler)
is_initialized(sampler::TabuSampler) = true

"""
    select_variables(
        ::Initialized,
        sampler::TabuSampler,
        model::AbstractModel,
        number_of_variables_to_move::Int,
        rng::AbstractRNG,
        mask::BitVector
    )

Selects variables while respecting tabu restrictions.

# Arguments
- `::Initialized`: Type parameter indicating initialization
- `sampler::TabuSampler`: The tabu sampler instance
- `model::AbstractModel`: The optimization model
- `number_of_variables_to_move::Int`: Number of variables to select
- `rng::AbstractRNG`: Random number generator
- `mask::BitVector`: Basic availability mask

# Returns
Vector of selected DecisionVariable instances

# Process
1. Creates tabu mask based on waiting times and current iteration
2. Uses subsampler to select from non-tabu variables
3. Updates tabu status for selected variables
4. Advances iteration counter

# Notes
- If insufficient non-tabu variables available, advances iterations until enough become available
- Maintains tabu status through minimal_iteration_number vector
"""
function select_variables(
    ::Initialized,
    sampler::TabuSampler,
    model::AbstractModel,
    number_of_variables_to_move::Int,
    rng::AbstractRNG,
    mask::BitVector,
)
    _is_valid(sampler, number_of_variables_to_move, mask)
    tabu_index_mask = _get_tabu_mask(rng, sampler, number_of_variables_to_move, mask)

    selected_variables = select_variables(sampler.subsampler, model, number_of_variables_to_move, rng, tabu_index_mask)
    indexes = [var.index for var in selected_variables]
    sampler.minimal_iteration_number[indexes, :] .= sampler.current_iteration + sampler.waiting_time

    return selected_variables
end

"""
    _get_tabu_mask(
        rng::AbstractRNG,
        sampler::TabuSampler,
        number_of_variables_to_move::Int,
        origin_mask::BitVector
    )

Internal function to generate the tabu mask.

# Arguments
- `rng::AbstractRNG`: Random number generator
- `sampler::TabuSampler`: The tabu sampler instance
- `number_of_variables_to_move::Int`: Required number of variables
- `origin_mask::BitVector`: Basic availability mask

# Returns
BitVector indicating which variables are available (not tabu)

# Process
1. Creates mask based on minimal iteration numbers and original mask
2. If insufficient variables available, advances iteration and recurses
3. Returns final mask when enough variables available

# Notes
- Recursive calls advance iterations until sufficient variables available
- Should only be called from select_variables to avoid infinite recursion
"""
function _get_tabu_mask(
    rng::AbstractRNG,
    sampler::TabuSampler,
    number_of_variables_to_move::Int,
    origin_mask::BitVector,
)
    index_mask = (sampler.minimal_iteration_number .<= sampler.current_iteration) .& origin_mask
    sampler.current_iteration += 1

    if sum(index_mask) < number_of_variables_to_move
        return _get_tabu_mask(rng, sampler, number_of_variables_to_move, origin_mask)
    end
    return index_mask
end


@testitem "select_variables(::TabuSampler) with CombinationHints" begin
    using Random
    struct MockModel <: JuLS.AbstractModel end
    JuLS.decision_variables(::MockModel) =
        JuLS.DecisionVariable[JuLS.DecisionVariable(i, JuLS.IntDecisionValue(i)) for i = 1:5]
    combination_set_matrix = falses(2, 5)
    combination_set_matrix[1, 1] = 1
    combination_set_matrix[1, 3] = 1
    combination_set_matrix[1, 4] = 1
    combination_hints = JuLS.CombinationHints(combination_set_matrix)

    sampler = JuLS.TabuSampler(2, combination_hints)

    rng = Random.MersenneTwister(0)

    first_sample = JuLS.select_variables(sampler, MockModel(), 1, rng, trues(5))[1].index
    second_sample = JuLS.select_variables(sampler, MockModel(), 1, rng, trues(5))[1].index
    third_sample = JuLS.select_variables(sampler, MockModel(), 1, rng, trues(5))[1].index

    @test all(s -> s in [1, 3, 4], [first_sample, second_sample, third_sample])

    @test JuLS.select_variables(sampler, MockModel(), 1, rng, trues(5))[1].index == first_sample
    @test JuLS.select_variables(sampler, MockModel(), 1, rng, trues(5))[1].index == second_sample
    @test JuLS.select_variables(sampler, MockModel(), 1, rng, trues(5))[1].index == third_sample
    @test JuLS.select_variables(sampler, MockModel(), 1, rng, trues(5))[1].index == first_sample
    @test JuLS.select_variables(sampler, MockModel(), 1, rng, trues(5))[1].index == second_sample
    @test JuLS.select_variables(sampler, MockModel(), 1, rng, trues(5))[1].index == third_sample
    @test JuLS.select_variables(sampler, MockModel(), 1, rng, trues(5))[1].index == first_sample
    @test JuLS.select_variables(sampler, MockModel(), 1, rng, trues(5))[1].index == second_sample
    @test JuLS.select_variables(sampler, MockModel(), 1, rng, trues(5))[1].index == third_sample
end

@testitem "select_variables(::TabuSampler) with CombinationHints 2" begin
    using Random
    struct MockModel <: JuLS.AbstractModel end
    JuLS.decision_variables(::MockModel) =
        JuLS.DecisionVariable[JuLS.DecisionVariable(i, JuLS.IntDecisionValue(i)) for i = 1:4]
    combination_set_matrix = falses(2, 4)
    combination_set_matrix[1, 1] = 1
    combination_set_matrix[1, 3] = 1
    combination_set_matrix[2, 2] = 1
    combination_set_matrix[2, 4] = 1
    combination_hints = JuLS.CombinationHints(combination_set_matrix)

    sampler = JuLS.TabuSampler(3, combination_hints)

    rng = Random.MersenneTwister(0)

    @test Set([var.index for var in JuLS.select_variables(sampler, MockModel(), 2, rng, trues(4))]) == Set([1, 3])
    @test Set([var.index for var in JuLS.select_variables(sampler, MockModel(), 2, rng, trues(4))]) == Set([2, 4])
    @test Set([var.index for var in JuLS.select_variables(sampler, MockModel(), 2, rng, trues(4))]) == Set([1, 3])
    @test Set([var.index for var in JuLS.select_variables(sampler, MockModel(), 2, rng, trues(4))]) == Set([2, 4])
    @test Set([var.index for var in JuLS.select_variables(sampler, MockModel(), 2, rng, trues(4))]) == Set([1, 3])
    @test Set([var.index for var in JuLS.select_variables(sampler, MockModel(), 2, rng, trues(4))]) == Set([2, 4])
end

@testitem "TabuSampler errors" begin
    using Random
    struct MockModel <: JuLS.AbstractModel end
    rng = Random.MersenneTwister(0)

    @test_throws ErrorException("There are not enough variables!") JuLS.select_variables(
        JuLS.TabuSampler(1, 2),
        MockModel(),
        10,
        rng,
        trues(2),
    ) # Too many variables to move
    @test_throws ErrorException("It is impossible to sample from this origin mask.") JuLS.select_variables(
        JuLS.TabuSampler(1, 2),
        MockModel(),
        1,
        rng,
        BitVector([0, 0]),
    )
end