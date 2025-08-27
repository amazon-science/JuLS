# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    CompositeNeighbourhoodHeuristic <: NeighbourhoodHeuristic
    CompositeMoveSelectionHeuristic <: MoveSelectionHeuristic

Composite structures that manage sequences of heuristics during optimization.

# Fields
- `counter::Int`: Number of times current heuristic has been used
- `heuristics_list::Vector`: List of heuristics to use
- `iterations_list::Vector{Int64}`: Number of iterations for each heuristic
- `current_index::Int`: Index of currently active heuristic

# Description
These structures enable dynamic switching between different heuristics during
optimization. They track usage and automatically switch heuristics based on
the specified iteration counts.
"""
mutable struct CompositeNeighbourhoodHeuristic <: NeighbourhoodHeuristic
    counter::Int
    heuristics_list::Vector{<:NeighbourhoodHeuristic}
    iterations_list::Vector{Int64}
    current_index::Int
end

mutable struct CompositeMoveSelectionHeuristic <: MoveSelectionHeuristic
    counter::Int
    heuristics_list::Vector{<:MoveSelectionHeuristic}
    iterations_list::Vector{Int64}
    current_index::Int
end

"""
    CompositeNeighbourhoodHeuristic(
        heuristics_list::Vector{<:NeighbourhoodHeuristic},
        iterations_list::Vector{Int64}
    )
    
    CompositeMoveSelectionHeuristic(
        heuristics_list::Vector{<:MoveSelectionHeuristic},
        iterations_list::Vector{Int64}
    )

Constructors for composite heuristics.
"""
function CompositeNeighbourhoodHeuristic(
    heuristics_list::Vector{<:NeighbourhoodHeuristic},
    iterations_list::Vector{Int64},
)
    @assert length(heuristics_list) == length(iterations_list)
    return CompositeNeighbourhoodHeuristic(1, heuristics_list, iterations_list, 1)
end

function CompositeMoveSelectionHeuristic(
    heuristics_list::Vector{<:MoveSelectionHeuristic},
    iterations_list::Vector{Int64},
)
    @assert length(heuristics_list) == length(iterations_list)
    return CompositeMoveSelectionHeuristic(1, heuristics_list, iterations_list, 1)
end

"""
    get_current_heuristic!(composite_heuristic::Union{CompositeMoveSelectionHeuristic,CompositeNeighbourhoodHeuristic})

Manages heuristic switching and returns current active heuristic.

# Process
1. Gets current heuristic
2. Increments usage counter
3. Checks if switch needed:
   - If counter exceeds iteration limit and not last heuristic:
     * Resets counter
     * Advances to next heuristic
4. Returns active heuristic
"""
function get_current_heuristic!(
    composite_heuristic::Union{CompositeMoveSelectionHeuristic,CompositeNeighbourhoodHeuristic},
)
    current_heuristic = get_current_heuristic(composite_heuristic)
    composite_heuristic.counter += 1

    if composite_heuristic.counter > composite_heuristic.iterations_list[composite_heuristic.current_index] &&
       composite_heuristic.current_index < length(composite_heuristic.iterations_list)
        composite_heuristic.counter = 1
        composite_heuristic.current_index += 1
    end
    return current_heuristic
end
get_current_heuristic(composite_heuristic::Union{CompositeMoveSelectionHeuristic,CompositeNeighbourhoodHeuristic}) =
    composite_heuristic.heuristics_list[composite_heuristic.current_index]

"""
    get_neighbourhood(
        composite_heuristic::CompositeNeighbourhoodHeuristic,
        m::AbstractModel;
        rng = Random.GLOBAL_RNG,
        mask = _default_mask(get_current_heuristic(composite_heuristic), m)
    )

Generates neighbourhood using current active neighbourhood heuristic.
"""
get_neighbourhood(
    composite_heuristic::CompositeNeighbourhoodHeuristic,
    m::AbstractModel;
    rng = Random.GLOBAL_RNG,
    mask = _default_mask(get_current_heuristic(composite_heuristic), m),
) = get_neighbourhood(get_current_heuristic!(composite_heuristic), m; rng, mask)

"""
    pick_a_move(
        composite_heuristic::CompositeMoveSelectionHeuristic,
        evaluated_moves::Vector{<:MoveEvaluatorOutput};
        rng = Random.GLOBAL_RNG
    )

Selects a move using current active move selection heuristic.
"""
pick_a_move(
    composite_heuristic::CompositeMoveSelectionHeuristic,
    evaluated_moves::Vector{<:MoveEvaluatorOutput};
    rng = Random.GLOBAL_RNG,
) = pick_a_move(get_current_heuristic!(composite_heuristic), evaluated_moves::Vector{<:MoveEvaluatorOutput}; rng)

@testitem "CompositeHeuristic definition" begin
    struct MockNeighbourhoodHeuristicOne <: JuLS.NeighbourhoodHeuristic end
    struct MockNeighbourhoodHeuristicTwo <: JuLS.NeighbourhoodHeuristic end

    struct MockMoveSelectionHeuristicOne <: JuLS.MoveSelectionHeuristic end
    struct MockMoveSelectionHeuristicTwo <: JuLS.MoveSelectionHeuristic end

    composite_heuristic = JuLS.CompositeNeighbourhoodHeuristic([MockNeighbourhoodHeuristicOne()], [1])
    @test composite_heuristic.counter == 1
    @test length(composite_heuristic.heuristics_list) == 1
    @test typeof(composite_heuristic.heuristics_list[1]) <: JuLS.NeighbourhoodHeuristic
    @test length(composite_heuristic.iterations_list) == 1
    @test composite_heuristic.current_index == 1

    composite_heuristic = JuLS.CompositeMoveSelectionHeuristic([MockMoveSelectionHeuristicOne()], [1])
    @test composite_heuristic.counter == 1
    @test length(composite_heuristic.heuristics_list) == 1
    @test typeof(composite_heuristic.heuristics_list[1]) <: JuLS.MoveSelectionHeuristic
    @test length(composite_heuristic.iterations_list) == 1
    @test composite_heuristic.current_index == 1
end

@testitem "get_current_heuristic!" begin
    struct MockNeighbourhoodHeuristic1 <: JuLS.NeighbourhoodHeuristic end
    struct MockNeighbourhoodHeuristic2 <: JuLS.NeighbourhoodHeuristic end

    struct MockMoveSelectionHeuristic1 <: JuLS.MoveSelectionHeuristic end
    struct MockMoveSelectionHeuristic2 <: JuLS.MoveSelectionHeuristic end

    composite_heuristic =
        JuLS.CompositeNeighbourhoodHeuristic([MockNeighbourhoodHeuristic1(), MockNeighbourhoodHeuristic2()], [1, 1])
    neigh = JuLS.get_current_heuristic!(composite_heuristic)
    @test typeof(neigh) == MockNeighbourhoodHeuristic1
    neigh = JuLS.get_current_heuristic!(composite_heuristic)
    @test typeof(neigh) == MockNeighbourhoodHeuristic2
    neigh = JuLS.get_current_heuristic!(composite_heuristic)
    @test typeof(neigh) == MockNeighbourhoodHeuristic2

    composite_heuristic2 =
        JuLS.CompositeMoveSelectionHeuristic([MockMoveSelectionHeuristic1(), MockMoveSelectionHeuristic2()], [1, 1])
    neigh = JuLS.get_current_heuristic!(composite_heuristic2)
    @test typeof(neigh) == MockMoveSelectionHeuristic1
    neigh = JuLS.get_current_heuristic!(composite_heuristic2)
    @test typeof(neigh) == MockMoveSelectionHeuristic2
    neigh = JuLS.get_current_heuristic!(composite_heuristic2)
    @test typeof(neigh) == MockMoveSelectionHeuristic2
end

@testitem "get_neighbourhood(::CompositeHeuristic)" begin
    using Random

    struct MockNeighbourhoodHeuristicOne <: JuLS.NeighbourhoodHeuristic end
    struct MockNeighbourhoodHeuristicTwo <: JuLS.NeighbourhoodHeuristic end

    rng = Random.MersenneTwister(0)

    #dummy get_neighbourhood for Mock1
    function JuLS.get_neighbourhood(
        heuristic::MockNeighbourhoodHeuristicOne,
        m::JuLS.AbstractModel;
        rng,
        mask::BitVector,
    )
        return 1
    end
    #dummy get_neighbourhood for Mock2
    function JuLS.get_neighbourhood(
        heuristic::MockNeighbourhoodHeuristicTwo,
        m::JuLS.AbstractModel;
        rng,
        mask::BitVector,
    )
        return 2
    end

    JuLS._default_mask(::MockNeighbourhoodHeuristicOne, m::JuLS.AbstractModel) =
        trues(length(JuLS.decision_variables(m)))

    JuLS._default_mask(heuristic::MockNeighbourhoodHeuristicTwo, m::JuLS.AbstractModel) =
        trues(length(JuLS.decision_variables(m)))

    heuristic1 = MockNeighbourhoodHeuristicOne()
    heuristic2 = MockNeighbourhoodHeuristicTwo()

    composite_heuristic = JuLS.CompositeNeighbourhoodHeuristic([heuristic1, heuristic2], [2, 3])

    e = JuLS.KnapsackExperiment(JuLS.PROJECT_ROOT * "/data/knapsack/ks_4_0")
    m = JuLS.init_model(e)

    @test all(
        [
            [
                JuLS.get_neighbourhood(composite_heuristic, m; rng, mask = JuLS._default_mask(heuristic1, m)),
                composite_heuristic.counter,
                composite_heuristic.current_index,
            ] for i ∈ 1:2
        ] .== [[1, 2, 1], [1, 1, 2]],
    )

    @test all(
        [
            [
                JuLS.get_neighbourhood(composite_heuristic, m; rng, mask = JuLS._default_mask(heuristic2, m)),
                composite_heuristic.counter,
                composite_heuristic.current_index,
            ] for i ∈ 0:2
        ] .== [[2, 2, 2], [2, 3, 2], [2, 4, 2]],
    )

    composite_heuristic_two = JuLS.CompositeNeighbourhoodHeuristic([heuristic1, heuristic2], [2, 3])

    @test JuLS.get_neighbourhood(composite_heuristic_two, m; rng, mask = falses(length(JuLS.decision_variables(m)))) ==
          1
end

@testitem "pick_a_move(::CompositeHeuristic)" begin
    using Random

    struct MockMoveSelectionHeuristicOne <: JuLS.MoveSelectionHeuristic end
    struct MockMoveSelectionHeuristicTwo <: JuLS.MoveSelectionHeuristic end
    struct MockEvaluatorOutputs <: JuLS.MoveEvaluatorOutput end

    rng = Random.MersenneTwister(0)

    #dummy pick_a_move for Mock1
    function JuLS.pick_a_move(::MockMoveSelectionHeuristicOne, ::Vector{<:JuLS.MoveEvaluatorOutput}; rng)
        return 1
    end
    #dummy pick_a_move for Mock2
    function JuLS.pick_a_move(::MockMoveSelectionHeuristicTwo, ::Vector{<:JuLS.MoveEvaluatorOutput}; rng)
        return 2
    end

    heuristic1 = MockMoveSelectionHeuristicOne()
    heuristic2 = MockMoveSelectionHeuristicTwo()

    composite_heuristic = JuLS.CompositeMoveSelectionHeuristic([heuristic1, heuristic2], [2, 3])

    evaluated_moves = [MockEvaluatorOutputs()]

    @test all(
        [
            [
                JuLS.pick_a_move(composite_heuristic, evaluated_moves; rng),
                composite_heuristic.counter,
                composite_heuristic.current_index,
            ] for i ∈ 1:2
        ] .== [[1, 2, 1], [1, 1, 2]],
    )

    @test all(
        [
            [
                JuLS.pick_a_move(composite_heuristic, evaluated_moves; rng),
                composite_heuristic.counter,
                composite_heuristic.current_index,
            ] for i ∈ 0:2
        ] .== [[2, 2, 2], [2, 3, 2], [2, 4, 2]],
    )
end