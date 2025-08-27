# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    create_tsp_dag(distance_matrix::Matrix{Float64})

Creates a Directed Acyclic Graph (DAG) representing the Traveling Salesman Problem constraints
and objective function.

# Arguments
- `distance_matrix::Matrix{Float64}`: Square matrix of distances between cities
- `α::Float64`: Penalty parameter for constraint

# Returns
A DAG object representing the TSP problem structure

# DAG Structure
1. All-Different Constraint:
   - Ensures each city is visited exactly once
   - Applied to all n variables

2. Distance Calculations:
   For each pair of cities (i,j) where i < j:
   - Checks if cities are consecutive in tour
   - Scales consecutive check by distance between cities

3. Objective Function:
   - Sums all scaled distances
   - Represents total tour length

4. Final Aggregator:
   - Combines all-different constraint with objective
   - Ensures both feasibility and optimization

# Graph Components
- Variables (n): City positions in tour
- Invariants:
  * AllDifferentInvariant: Tour permutation constraint
  * ConsecutiveInvariant: Detects adjacent cities
  * ScaleInvariant: Applies distance weights
  * ObjectiveInvariant: Sums distances
  * AggregatorInvariant: Combines constraints
"""
function create_tsp_dag(distance_matrix::Matrix{<:Number}, α::Float64 = DEFAULT_PENALTY_PARAM)
    n = size(distance_matrix)[1]
    dag = DAG(n)

    alldiff_id = add_invariant!(
        dag,
        AllDifferentInvariant(n);
        variable_parent_indexes = collect(1:n),
        name = "all_diff_invariant",
    )

    constraint_id = add_invariant!(dag, StaticConstraintInvariant(α); invariant_parent_indexes = [alldiff_id])

    distance_ids = Int[]
    for i = 1:n
        for j = i+1:n
            is_consecutive_id = add_invariant!(
                dag,
                ConsecutiveInvariant(1, n);
                variable_parent_indexes = [i, j],
                name = "is_consecutive_$(i)_$(j)",
            )
            push!(
                distance_ids,
                add_invariant!(
                    dag,
                    ScaleInvariant(distance_matrix[i, j]);
                    invariant_parent_indexes = [is_consecutive_id],
                ),
            )
        end
    end
    obj_id =
        add_invariant!(dag, ObjectiveInvariant(); invariant_parent_indexes = distance_ids, name = "objective_invariant")

    add_invariant!(dag, AggregatorInvariant(); invariant_parent_indexes = [constraint_id, obj_id])

    return dag
end

@testitem "Test tsp eval 1" begin
    distance_matrix = [
        0.0 2.0 9.0 10.0
        2.0 0.0 6.0 4.0
        9.0 6.0 0.0 3.0
        10.0 4.0 3.0 0.0
    ]

    dag = JuLS.create_tsp_dag(distance_matrix)
    decision_variables = [JuLS.DecisionVariable(i, JuLS.IntDecisionValue(i)) for i = 1:4]
    JuLS.init!(dag, JuLS.DecisionVariablesArray(decision_variables))

    move = JuLS.Move(decision_variables[[1, 2]], [JuLS.IntDecisionValue(2), JuLS.IntDecisionValue(1)])

    evaluated_move = JuLS.eval(dag, move)

    @test JuLS.delta_obj(evaluated_move) == -3
    @test JuLS.isfeasible(evaluated_move)
end


@testitem "Test tsp eval 2" begin
    distance_matrix = [
        0.0 2.0 9.0 10.0
        2.0 0.0 6.0 4.0
        9.0 6.0 0.0 3.0
        10.0 4.0 3.0 0.0
    ]

    dag = JuLS.create_tsp_dag(distance_matrix)
    decision_variables = [JuLS.DecisionVariable(i, JuLS.IntDecisionValue(i)) for i = 1:4]
    JuLS.init!(dag, JuLS.DecisionVariablesArray(decision_variables))

    move = JuLS.Move(decision_variables[[1, 2]], [JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(1)])

    evaluated_move = JuLS.eval(dag, move)

    @test JuLS.delta_obj(evaluated_move) == Inf
    @test !JuLS.isfeasible(evaluated_move)
end


@testitem "Test tsp commit!" begin
    distance_matrix = [
        0.0 2.0 9.0 10.0
        2.0 0.0 6.0 4.0
        9.0 6.0 0.0 3.0
        10.0 4.0 3.0 0.0
    ]

    dag = JuLS.create_tsp_dag(distance_matrix)
    decision_variables = [JuLS.DecisionVariable(i, JuLS.IntDecisionValue(i)) for i = 1:4]
    JuLS.init!(dag, JuLS.DecisionVariablesArray(decision_variables))

    move = JuLS.Move(decision_variables[[1, 2]], [JuLS.IntDecisionValue(2), JuLS.IntDecisionValue(1)])

    JuLS.commit!(dag, JuLS.eval(dag, move))

    evaluated_move =
        JuLS.eval(dag, JuLS.Move(decision_variables[[1, 2]], [JuLS.IntDecisionValue(1), JuLS.IntDecisionValue(2)]))

    @test JuLS.delta_obj(evaluated_move) == 3
    @test JuLS.isfeasible(evaluated_move)
end

@testitem "Test tsp commit! 2" begin
    distance_matrix = [
        0.0 2.0 9.0 10.0
        2.0 0.0 6.0 4.0
        9.0 6.0 0.0 3.0
        10.0 4.0 3.0 0.0
    ]

    dag = JuLS.create_tsp_dag(distance_matrix)
    decision_variables = [JuLS.DecisionVariable(i, JuLS.IntDecisionValue(i)) for i = 1:4]
    JuLS.init!(dag, JuLS.DecisionVariablesArray(decision_variables))

    move = JuLS.Move(decision_variables[[1, 2]], [JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(1)])

    @test_throws ErrorException JuLS.commit!(dag, JuLS.eval(dag, move)) # Infeasible move that caused an early stop

    evaluated_move = JuLS.eval(dag, move) # So the move is still infeasible

    @test JuLS.delta_obj(evaluated_move) == Inf
    @test !JuLS.isfeasible(evaluated_move)
end

@testitem "TSP full eval" begin
    distance_matrix = [
        0.0 2.0 9.0 10.0
        2.0 0.0 6.0 4.0
        9.0 6.0 0.0 3.0
        10.0 4.0 3.0 0.0
    ]

    dag = JuLS.create_tsp_dag(distance_matrix)
    decision_variables = [JuLS.DecisionVariable(i, JuLS.IntDecisionValue(i)) for i = 1:4]
    JuLS.init!(dag, JuLS.DecisionVariablesArray(decision_variables))

    solution1 = JuLS.Solution(JuLS.eval(dag, JuLS.DecisionVariablesArray(decision_variables)))

    @test solution1.values == [JuLS.IntDecisionValue(i) for i = 1:4]
    @test solution1.objective == 21
    @test solution1.feasible

    position = [3, 1, 4, 2]
    decision_variables = [JuLS.DecisionVariable(i, JuLS.IntDecisionValue(position[i])) for i = 1:4]
    solution2 = JuLS.Solution(JuLS.eval(dag, JuLS.DecisionVariablesArray(decision_variables)))


    @test solution2.values ==
          [JuLS.IntDecisionValue(3), JuLS.IntDecisionValue(1), JuLS.IntDecisionValue(4), JuLS.IntDecisionValue(2)]
    @test solution2.objective == 29
    @test solution2.feasible

end

@testitem "α default assignment in create_tsp_dag()" begin
    distance_matrix = [
        0.0 2.0 9.0 10.0
        2.0 0.0 6.0 4.0
        9.0 6.0 0.0 3.0
        10.0 4.0 3.0 0.0
    ]

    position = [1, 2, 3, 1]
    dag = JuLS.create_tsp_dag(distance_matrix)
    decision_variables = [JuLS.DecisionVariable(i, JuLS.IntDecisionValue(position[i])) for i = 1:4]
    JuLS.init!(dag, JuLS.DecisionVariablesArray(decision_variables))

    solution1 = JuLS.Solution(JuLS.eval(dag, JuLS.DecisionVariablesArray(decision_variables)))

    dag2 = JuLS.create_tsp_dag(distance_matrix, 0.0)
    JuLS.init!(dag2, JuLS.DecisionVariablesArray(decision_variables))

    solution2 = JuLS.Solution(JuLS.eval(dag2, JuLS.DecisionVariablesArray(decision_variables)))

    @test solution1.objective == 22 # 12 + alpha (1 violation)
    @test solution2.objective == 12
end
