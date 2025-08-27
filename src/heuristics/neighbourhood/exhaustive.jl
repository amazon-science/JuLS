# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    ExhaustiveNeighbourhood <: NeighbourhoodHeuristic

A neighbourhood generation strategy that exhaustively explores all possible value combinations for a selected subset of variables.
This is equivalent to relax domains for the variables sampled.

# Fields
- `number_of_variables_to_move::Int`: Number of variables to consider in each move
- `variable_sampler::VariableSampler`: Strategy for selecting which variables to consider
"""
struct ExhaustiveNeighbourhood <: NeighbourhoodHeuristic
    number_of_variables_to_move::Int
    variable_sampler::VariableSampler
end


"""
    ExhaustiveNeighbourhood(number_of_variables_to_move::Int, total_number_of_variables::Int)

Convenience constructor that creates an ExhaustiveNeighbourhood with a ClassicSampler.

# Arguments
- `number_of_variables_to_move::Int`: Number of variables to modify in each move
- `total_number_of_variables::Int`: Total number of variables in the problem
"""
ExhaustiveNeighbourhood(number_of_variables_to_move::Int, total_number_of_variables::Int) =
    ExhaustiveNeighbourhood(number_of_variables_to_move, ClassicSampler(total_number_of_variables))

_default_mask(neighbourhood::ExhaustiveNeighbourhood, m::AbstractModel) =
    _default_mask(neighbourhood.variable_sampler, m)

"""
	struct LazyCartesianMoves <: AbstractArray{MoveEvaluatorInput,1}

Return type of `ExhaustiveNeighbourhood`. The moves are only generated when needed.
Implements lazy move generation where moves are only created when accessed.
Behaves like a regular array but generates moves on-demand to save memory.
"""
struct LazyCartesianMoves <: AbstractArray{Move,1}
    selected_variables::Vector{DecisionVariable}
    indices::CartesianIndices
end
LazyCartesianMoves(selected_variables::Vector{DecisionVariable}) = LazyCartesianMoves(
    selected_variables,
    CartesianIndices(Tuple([length(variable.domain) for variable in selected_variables])),
)

Base.size(moves::LazyCartesianMoves) = (length(moves.indices) + 1,)
Base.IndexStyle(::LazyCartesianMoves) = IndexLinear()
function Base.getindex(moves::LazyCartesianMoves, i::Int)
    if i == length(moves)
        return JuLS.NO_MOVE
    end
    return Move(
        moves.selected_variables,
        [var.domain[val_index] for (var, val_index) in zip(moves.selected_variables, Tuple(moves.indices[i]))],
    )
end

decision_types(array::LazyCartesianMoves) = [typeof(var.current_value) for var in array.selected_variables]

"""
	get_neighbourhood(h::ExhaustiveNeighbourhood, model::Model; rng=Random.GLOBAL_RNG)

Samples a set of variables and computes a set of moves based on the cartesian product of the possible variable values.
"""
get_neighbourhood(
    h::ExhaustiveNeighbourhood,
    model::Model;
    rng = Random.default_rng(),
    mask::BitVector = _default_mask(h, model),
) = LazyCartesianMoves(select_variables(h.variable_sampler, model, h.number_of_variables_to_move, rng, mask))


@testitem "decision_type(::LazyCartesianMoves)" begin
    s1 = JuLS.DecisionVariable(1, JuLS.IntDecisionValue.(collect(1:3)), JuLS.IntDecisionValue(3))
    s2 = JuLS.DecisionVariable(2, JuLS.BinaryDecisionValue.(collect(0:1)), JuLS.BinaryDecisionValue(1))
    decision_variables = JuLS.DecisionVariable[s1, s2]

    neigh = JuLS.LazyCartesianMoves(decision_variables)
    @test JuLS.decision_types(neigh) == [JuLS.IntDecisionValue, JuLS.BinaryDecisionValue]
end

@testitem "LazyCartesianMoves" begin

    s1 = JuLS.DecisionVariable(1, JuLS.IntDecisionValue.(collect(1:3)), JuLS.IntDecisionValue(3))
    s2 = JuLS.DecisionVariable(2, JuLS.IntDecisionValue.(collect(1:2)), JuLS.IntDecisionValue(1))
    decision_variables = JuLS.DecisionVariable[s1, s2]

    neigh = JuLS.LazyCartesianMoves(decision_variables)

    @test length(neigh) == 7
    @test all([neigh[i].variables == decision_variables for i = 1:6])

    @test neigh[1].new_values == JuLS.IntDecisionValue.([1, 1])
    @test neigh[2].new_values == JuLS.IntDecisionValue.([2, 1])
    @test neigh[3].new_values == JuLS.IntDecisionValue.([3, 1])
    @test neigh[4].new_values == JuLS.IntDecisionValue.([1, 2])
    @test neigh[5].new_values == JuLS.IntDecisionValue.([2, 2])
    @test neigh[6].new_values == JuLS.IntDecisionValue.([3, 2])
    @test neigh[7] == JuLS.NO_MOVE
end

@testitem "get_neighbourhood(::ExhaustiveNeighbourhood) with ClassicSampler" begin
    using Random

    value1 = JuLS.IntDecisionValue(2)
    value2 = JuLS.IntDecisionValue(1)
    value3 = JuLS.IntDecisionValue(2)
    domain = JuLS.DecisionValue.([1, 2])

    s1 = JuLS.DecisionVariable(1, domain, value1)
    s2 = JuLS.DecisionVariable(2, domain, value2)
    s3 = JuLS.DecisionVariable(3, domain, value3)
    decision_variables = JuLS.DecisionVariable[s1, s2, s3]

    h = JuLS.ExhaustiveNeighbourhood(2, JuLS.ClassicSampler(3))

    struct FakeDAG <: JuLS.MoveEvaluator end

    sol = JuLS.Solution([value1, value2, value3], 2.3, false)
    model = JuLS.Model(decision_variables, h, JuLS.GreedyMoveSelection(), FakeDAG(); current_solution = sol)

    rng = Random.MersenneTwister(0)
    neigh = JuLS.get_neighbourhood(h, model; rng)

    @test length(neigh) == 5
    @test neigh[2].variables == neigh[1].variables
    @test neigh[3].variables == neigh[1].variables
    @test neigh[4].variables == neigh[1].variables
    @test neigh.indices == CartesianIndices((2, 2))
    @test neigh[5] == JuLS.NO_MOVE
end

@testitem "get_neighbourhood(::ExhaustiveNeighbourhood) single variable" begin
    using Random

    number_of_values_per_variable = [1]
    value1 = JuLS.IntDecisionValue(1)
    s1 = JuLS.DecisionVariable(1, value1)
    decision_variables = JuLS.DecisionVariable[s1]

    h = JuLS.ExhaustiveNeighbourhood(1, JuLS.ClassicSampler(1))
    struct FakeDAG <: JuLS.MoveEvaluator end

    sol = JuLS.Solution([value1], 2.3, false)
    model = JuLS.Model(decision_variables, h, JuLS.GreedyMoveSelection(), FakeDAG(); current_solution = sol)

    rng = Random.MersenneTwister(0)
    neigh = JuLS.get_neighbourhood(h, model; rng)

    @test length(neigh) == 2
    @test neigh[2] == JuLS.NO_MOVE
end

@testitem "get_neighbourhood(::ExhaustiveNeighbourhood) replacement check" begin
    using Random

    value1 = JuLS.IntDecisionValue(3)
    value2 = JuLS.IntDecisionValue(1)
    number_of_values_per_variable = [3, 2]
    s1 = JuLS.DecisionVariable(1, value1)
    s2 = JuLS.DecisionVariable(2, value2)
    decision_variables = JuLS.DecisionVariable[s1, s2]

    h = JuLS.ExhaustiveNeighbourhood(2, JuLS.ClassicSampler(2))

    struct FakeDAG <: JuLS.MoveEvaluator end

    sol = JuLS.Solution([value1, value2], 2.3, false)
    model = JuLS.Model(decision_variables, h, JuLS.GreedyMoveSelection(), FakeDAG(); current_solution = sol)

    rng = Random.MersenneTwister(1)
    neigh = JuLS.get_neighbourhood(h, model; rng)

    @test neigh[1].variables[1].index == 2
    @test neigh[1].variables[2].index == 1
end

@testitem "get_neighbourhood(::ExhaustiveNeighbourhood) with TabuSampler" begin
    using Random

    domain = JuLS.IntDecisionValue.([1, 2, 3])
    s1 = JuLS.DecisionVariable(1, domain[1:3], domain[3])
    s2 = JuLS.DecisionVariable(2, domain[1:2], domain[1])
    decision_variables = JuLS.DecisionVariable[s1, s2]

    h = JuLS.ExhaustiveNeighbourhood(1, JuLS.TabuSampler(1, 2))

    struct FakeDAG <: JuLS.MoveEvaluator end

    sol = JuLS.Solution([domain[1], domain[2]], 2.3, false)
    model = JuLS.Model(decision_variables, h, JuLS.GreedyMoveSelection(), FakeDAG(); current_solution = sol)

    rng = Random.MersenneTwister(0)

    @test JuLS.get_neighbourhood(h, model; rng)[1].variables[1].index == 1
    @test JuLS.get_neighbourhood(h, model; rng)[1].variables[1].index == 2
    @test JuLS.get_neighbourhood(h, model; rng)[1].variables[1].index == 1
    @test JuLS.get_neighbourhood(h, model; rng)[1].variables[1].index == 2
    @test JuLS.get_neighbourhood(h, model; rng)[1].variables[1].index == 1
    @test JuLS.get_neighbourhood(h, model; rng)[1].variables[1].index == 2
    @test JuLS.get_neighbourhood(h, model; rng)[1].variables[1].index == 1
    @test JuLS.get_neighbourhood(h, model; rng)[1].variables[1].index == 2
    @test JuLS.get_neighbourhood(h, model; rng)[1].variables[1].index == 1
    @test JuLS.get_neighbourhood(h, model; rng)[1].variables[1].index == 2
    @test JuLS.get_neighbourhood(h, model; rng)[1].variables[1].index == 1
end

@testitem "get_neighbourhood(::ExhaustiveNeighbourhood) with TabuSampler 2" begin
    using Random

    domain = JuLS.IntDecisionValue.([1, 2, 3])
    s1 = JuLS.DecisionVariable(1, domain[1:3], domain[3])
    s2 = JuLS.DecisionVariable(2, domain[1:2], domain[1])
    decision_variables = JuLS.DecisionVariable[s1, s2]

    h = JuLS.ExhaustiveNeighbourhood(1, JuLS.TabuSampler(1, 2))

    struct FakeDAG <: JuLS.MoveEvaluator end

    sol = JuLS.Solution([domain[1], domain[2]], 2.3, false)
    model = JuLS.Model(decision_variables, h, JuLS.GreedyMoveSelection(), FakeDAG(); current_solution = sol)

    rng = Random.MersenneTwister(0)

    @test JuLS.get_neighbourhood(h, model; rng, mask = BitVector([0, 1]))[1].variables[1].index == 2
    @test JuLS.get_neighbourhood(h, model; rng, mask = BitVector([0, 1]))[1].variables[1].index == 2
    @test JuLS.get_neighbourhood(h, model; rng, mask = BitVector([0, 1]))[1].variables[1].index == 2
end


@testitem "select_variables with hints" begin
    using Random

    struct MockModel <: JuLS.AbstractModel
        decision_variables::Array{JuLS.DecisionVariable}
    end

    domain = JuLS.IntDecisionValue.([1, 2, 3])
    s1 = JuLS.DecisionVariable(1, domain[1:3], domain[3])
    s2 = JuLS.DecisionVariable(2, domain[1:2], domain[1])
    decision_variables = JuLS.DecisionVariable[s1, s2]

    model = MockModel(decision_variables)

    combination_set_matrix = falses(1, 3)
    combination_set_matrix[1, 1] = 1

    variable_sampler1 = JuLS.CombinationHints(combination_set_matrix)
    mask = trues(3)
    rng = Random.MersenneTwister(0)

    # It's constant with hints!
    @test JuLS.select_variables(variable_sampler1, model, 1, rng, mask) == [s1]
    @test JuLS.select_variables(variable_sampler1, model, 1, rng, mask) == [s1]
    @test JuLS.select_variables(variable_sampler1, model, 1, rng, mask) == [s1]
    @test JuLS.select_variables(variable_sampler1, model, 1, rng, mask) == [s1]

    combination_set_matrix2 = falses(1, 3)
    combination_set_matrix2[1, 2] = 1
    variable_sampler2 = JuLS.CombinationHints(combination_set_matrix2)

    @test JuLS.select_variables(variable_sampler2, model, 1, rng, mask) == [s2]
    @test JuLS.select_variables(variable_sampler2, model, 1, rng, mask) == [s2]
    @test JuLS.select_variables(variable_sampler2, model, 1, rng, mask) == [s2]
    @test JuLS.select_variables(variable_sampler2, model, 1, rng, mask) == [s2]
end

