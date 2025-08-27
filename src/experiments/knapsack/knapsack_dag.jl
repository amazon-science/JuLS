# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    create_knapsack_dag(
        weights::Array{Int}, 
        values::Array{Int}, 
        capacity::Int, 
        α::Float64 = DEFAULT_PENALTY_PARAM
    )

Creates a Directed Acyclic Graph (DAG) representing the Knapsack Problem constraints
and objective function.

# Arguments
- `weights::Array{Int}`: Array of item weights
- `values::Array{Int}`: Array of item values
- `capacity::Int`: Knapsack capacity
- `α::Float64`: Penalty parameter for constraint violation (default: DEFAULT_PENALTY_PARAM)

# Returns
A DAG object representing the Knapsack problem structure

# DAG Structure
1. Item Selection:
   - Each item has a binary decision variable (0: not selected, 1: selected)

2. Value Calculation:
   - For each item: ScaleInvariant(-values[i])
   - Negative because we're minimizing (maximizing negative)

3. Weight Calculation:
   - For each item: ScaleInvariant(weights[i])
   - Used for constraint checking

4. Objective Function:
   - ObjectiveInvariant summing all scaled values

5. Capacity Constraint:
   - ComparatorInvariant checking total weight ≤ capacity

6. Penalty for Constraint Violation:
   - StaticConstraintInvariant applying penalty α for violations

7. Final Aggregator:
   - Combines objective and penalized constraint

# Graph Components
- Variables (n): Binary selections for each item
- Invariants:
  * ScaleInvariant: For item values and weights
  * ObjectiveInvariant: Sums negative values (for maximization)
  * ComparatorInvariant: Checks capacity constraint
  * StaticConstraintInvariant: Applies penalty for violations
  * AggregatorInvariant: Combines objective and constraint
"""
function create_knapsack_dag(weights::Array{Int}, values::Array{Int}, capacity::Int, α::Float64 = DEFAULT_PENALTY_PARAM)
    n_items = length(weights)

    dag = DAG(n_items)

    cost_nodes = zeros(Int, n_items)
    weight_nodes = zeros(Int, n_items)
    for i = 1:n_items
        cost_nodes[i] = add_invariant!(dag, ScaleInvariant(-values[i]); variable_parent_indexes = [i])
        weight_nodes[i] =
            add_invariant!(dag, ScaleInvariant(weights[i]); variable_parent_indexes = [i], using_cp = true)
    end
    obj_node =
        add_invariant!(dag, ObjectiveInvariant(); name = "objective_value", invariant_parent_indexes = cost_nodes)

    capacity_node = add_invariant!(
        dag,
        ComparatorInvariant(capacity);
        name = "constraint_violation",
        invariant_parent_indexes = weight_nodes,
        using_cp = true,
    )

    constraint_node = add_invariant!(dag, StaticConstraintInvariant(α); invariant_parent_indexes = [capacity_node])

    add_invariant!(dag, AggregatorInvariant(); invariant_parent_indexes = [constraint_node, obj_node])

    return dag
end

@testitem "Test knapsack eval 1" begin
    dag = JuLS.create_knapsack_dag([1, 2], [3, 4], 3)

    var1 = JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(false))
    var2 = JuLS.DecisionVariable(2, JuLS.BinaryDecisionValue(false))
    JuLS.init!(dag, JuLS.DecisionVariablesArray([var1, var2]))

    move = JuLS.Move([var1, var2], [JuLS.BinaryDecisionValue(true), JuLS.BinaryDecisionValue(true)])

    evaluated_move = JuLS.eval(dag, move)

    @test JuLS.delta_obj(evaluated_move) == -7
    @test JuLS.isfeasible(evaluated_move)
end


@testitem "Test knapsack eval 2" begin
    dag = JuLS.create_knapsack_dag([10, 2], [3, 4], 2)

    var1 = JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(false))
    var2 = JuLS.DecisionVariable(2, JuLS.BinaryDecisionValue(false))
    JuLS.init!(dag, JuLS.DecisionVariablesArray([var1, var2]))

    move = JuLS.Move([var1, var2], [JuLS.BinaryDecisionValue(true), JuLS.BinaryDecisionValue(true)])

    evaluated_move = JuLS.eval(dag, move)

    @test JuLS.delta_obj(evaluated_move) == Inf
    @test !JuLS.isfeasible(evaluated_move)
end


@testitem "Test knapsack commit! 1" begin
    dag = JuLS.create_knapsack_dag([1, 2], [3, 4], 3)

    var1 = JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(false))
    var2 = JuLS.DecisionVariable(2, JuLS.BinaryDecisionValue(false))

    JuLS.init!(dag, JuLS.DecisionVariablesArray([var1, var2]))

    move = JuLS.Move([var1, var2], [JuLS.BinaryDecisionValue(true), JuLS.BinaryDecisionValue(true)])

    JuLS.commit!(dag, JuLS.eval(dag, move))
    var1 = JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(true))
    var2 = JuLS.DecisionVariable(2, JuLS.BinaryDecisionValue(true))

    evaluated_move =
        JuLS.eval(dag, JuLS.Move([var1, var2], [JuLS.BinaryDecisionValue(false), JuLS.BinaryDecisionValue(false)]))

    @test JuLS.delta_obj(evaluated_move) == 7
    @test JuLS.isfeasible(evaluated_move)
end


@testitem "Test knapsack commit! 2" begin
    dag = JuLS.create_knapsack_dag([1, 2], [3, 4], 2)

    var1 = JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(false))
    var2 = JuLS.DecisionVariable(2, JuLS.BinaryDecisionValue(false))
    JuLS.init!(dag, JuLS.DecisionVariablesArray([var1, var2]))

    move = JuLS.Move([var1, var2], [JuLS.BinaryDecisionValue(true), JuLS.BinaryDecisionValue(true)])


    @test_throws ErrorException JuLS.commit!(dag, JuLS.eval(dag, move)) # Infeasible move that caused an early stop

    evaluated_move = JuLS.eval(dag, move) # So the move is still infeasible


    @test JuLS.delta_obj(evaluated_move) == Inf
    @test !JuLS.isfeasible(evaluated_move)
end

@testitem "Knapsack full eval" begin
    dag = JuLS.create_knapsack_dag([1, 2, 3], [3, 4, 5], 2)


    var1 = JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(false))
    var2 = JuLS.DecisionVariable(2, JuLS.BinaryDecisionValue(true))
    var3 = JuLS.DecisionVariable(3, JuLS.BinaryDecisionValue(false))
    JuLS.init!(dag, JuLS.DecisionVariablesArray([var1, var2, var3]))

    solution1 = JuLS.Solution(JuLS.eval(dag, JuLS.DecisionVariablesArray(JuLS.DecisionVariable[var1, var2, var3])))

    @test solution1.values ==
          [JuLS.BinaryDecisionValue(false), JuLS.BinaryDecisionValue(true), JuLS.BinaryDecisionValue(false)]
    @test solution1.objective == -4
    @test solution1.feasible

    var3 = JuLS.DecisionVariable(3, JuLS.BinaryDecisionValue(true))
    solution2 = JuLS.Solution(JuLS.eval(dag, JuLS.DecisionVariablesArray(JuLS.DecisionVariable[var1, var2, var3])))

    @test solution2.values ==
          [JuLS.BinaryDecisionValue(false), JuLS.BinaryDecisionValue(true), JuLS.BinaryDecisionValue(true)]
    @test solution2.objective == 21 # -9 + 30
    @test !solution2.feasible

end

@testitem "α default assignment in create_knapsack_dag()" begin

    var1 = JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(true))
    var2 = JuLS.DecisionVariable(2, JuLS.BinaryDecisionValue(true))
    var3 = JuLS.DecisionVariable(3, JuLS.BinaryDecisionValue(false))

    dag1 = JuLS.create_knapsack_dag([1, 2, 3], [3, 4, 5], 2)
    JuLS.init!(dag1, JuLS.DecisionVariablesArray([var1, var2, var3]))

    solution1 = JuLS.Solution(JuLS.eval(dag1, JuLS.DecisionVariablesArray(JuLS.DecisionVariable[var1, var2, var3])))

    dag2 = JuLS.create_knapsack_dag([1, 2, 3], [3, 4, 5], 2, 0.0)
    JuLS.init!(dag2, JuLS.DecisionVariablesArray([var1, var2, var3]))

    solution2 = JuLS.Solution(JuLS.eval(dag2, JuLS.DecisionVariablesArray(JuLS.DecisionVariable[var1, var2, var3])))

    @test solution1.objective == 3 # -3-4+alpha*max(0,2+1-capacity)
    @test solution2.objective == -7
end
