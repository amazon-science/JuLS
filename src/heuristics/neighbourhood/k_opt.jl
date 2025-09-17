# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    KOptNeighbourhood <: NeighbourhoodHeuristic

A neighbourhood generation strategy that creates k-opt moves by permuting values
among k selected variables.

# Fields
- `number_of_moves::Int`: Number of different k-opt moves to generate
- `k::Int`: Number of variables involved in each permutation

# Description
Implements a k-opt neighbourhood where k variables are selected and their values
are permuted to create new potential solutions. This is particularly useful for
problems
"""
struct KOptNeighbourhood <: NeighbourhoodHeuristic
    number_of_moves::Int
    k::Int
end


"""
    get_neighbourhood(
        h::KOptNeighbourhood,
        model::Model;
        rng = Random.GLOBAL_RNG
    )

Generates multiple sets of k-opt moves for the given model.

# Process
1. Generates h.number_of_moves sets of k-opt moves
2. Concatenates all moves into a single vector
3. Each set involves different randomly selected variables

# Notes
- Total number of moves = number_of_moves * (k! - 1)
"""
function get_neighbourhood(h::KOptNeighbourhood, model::Model; rng=Random.GLOBAL_RNG)
    return vcat(NO_MOVE, [_get_kopt_moves(h, model.decision_variables; rng) for idx = 1:h.number_of_moves]...)
end

"""
    _get_kopt_moves(
        h::KOptNeighbourhood,
        variables::Array{DecisionVariable};
        rng = Random.GLOBAL_RNG
    )

Generates one set of k-opt moves by permuting values among h.k selected variables.

# Process
1. Randomly selects k variables
2. Gets their current values
3. Generates all possible permutations of these values
4. Creates moves for each permutation (excluding the current arrangement)

# Notes
- Generates (k! - 1) moves per call (excludes the identity permutation)
"""
function _get_kopt_moves(h::KOptNeighbourhood, variables::Array{DecisionVariable}; rng=Random.GLOBAL_RNG)
    selected_variables = sample(rng, variables, h.k; replace=false)
    current = [IntDecisionValue(variable.current_value.value) for variable in selected_variables]
    permutations = collect(Combinatorics.permutations(current))[2:end] # the input array is always the first element of permutations
    return [Move(selected_variables, permutation) for permutation in permutations]
end

@testitem "_get_kopt_moves(::KOptNeighbourhood)" begin
    using Random
    heuristic1 = JuLS.KOptNeighbourhood(2, 3)
    heuristic2 = JuLS.KOptNeighbourhood(4, 4)

    var1 = JuLS.DecisionVariable(1, JuLS.IntDecisionValue(1))
    var2 = JuLS.DecisionVariable(2, JuLS.IntDecisionValue(2))
    var3 = JuLS.DecisionVariable(3, JuLS.IntDecisionValue(3))
    var4 = JuLS.DecisionVariable(4, JuLS.IntDecisionValue(4))
    var5 = JuLS.DecisionVariable(5, JuLS.IntDecisionValue(5))

    decision_variables = JuLS.DecisionVariable[var1, var2, var3, var4, var5]

    rng = Random.MersenneTwister(0)

    moves = JuLS._get_kopt_moves(heuristic1, decision_variables)

    @test length(moves) == 5

    move = moves[2]
    old = [current.current_value.value for current in move.variables]
    new = [new.value for new in move.new_values]

    @test length(move.variables) == 3
    @test length(move.new_values) == 3
    @test length(Set(var.index for var in move.variables)) == length(move.variables) ## variable indexes should be different
    @test length(Set(new)) == length(new)
    @test sort(old) == sort(new) # all elements from old should be in new assignment
    @test !all(old .== new) # old and new should be different

    moves = JuLS._get_kopt_moves(heuristic2, decision_variables)

    @test length(moves) == 23 # 4*3*2 - 1

end

@testitem "get_neighbourhood(::KOptNeighbourhood)" begin
    using Random
    struct FakeDAG <: JuLS.MoveEvaluator end

    heuristic1 = JuLS.KOptNeighbourhood(2, 3) # 2 * (3*2    -1) = 10
    heuristic2 = JuLS.KOptNeighbourhood(3, 4) # 3 * (4*3*2  -1) = 69

    sol = JuLS.Solution([JuLS.IntDecisionValue(idx) for idx = 1:5], 4.0, true)
    model = JuLS.Model(heuristic1, JuLS.GreedyMoveSelection(), FakeDAG(), sol)

    rng = Random.MersenneTwister(0)

    moves = JuLS.get_neighbourhood(heuristic1, model; rng)
    @test length(moves) == 11

    moves = JuLS.get_neighbourhood(heuristic2, model; rng)
    @test length(moves) == 70
end

