# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    create_graph_coloring_dag(
        n_nodes::Int,
        edges::Vector{Tuple{Int,Int}},
        max_color::Int,
        α::Float64 = DEFAULT_PENALTY_PARAM
    )

Creates a Directed Acyclic Graph (DAG) representing the Graph Coloring Problem objective.

# Arguments
- `n_nodes::Int`: Number of nodes in the graph
- `edges::Vector{Tuple{Int,Int}}`: List of edges in the graph, each represented as a tuple of two node indices
- `max_color::Int`: Maximum number of colors available
- `α::Float64`: Penalty parameter for constraint violations (default: DEFAULT_PENALTY_PARAM)

# Returns
A DAG object representing the Graph Coloring problem structure

# DAG Structure
1. Decision Variables:
   - Each node (1 to n_nodes) has an integer variable representing its color

2. Constraints:
   - Not Equal Constraints:
     * For each edge (i,j), creates a RelationalInvariant with NeOp
     * Ensures connected nodes have different colors
   - Static Constraint:
     * Combines all not-equal constraints with penalty α

3. Objective Components:
   - Maximum Color:
     * Tracks the highest color number used
     * Implemented using MaximumInvariant
   - Objective Function:
     * Minimizes the maximum color used
     * Combined with penalized constraints using AggregatorInvariant
"""
function create_graph_coloring_dag(
    n_nodes::Int,
    edges::Vector{Tuple{Int,Int}},
    max_color::Int,
    α::Float64 = DEFAULT_PENALTY_PARAM,
)
    dag = DAG(n_nodes; early_stop_threshold = length(edges) * α)

    not_equal_ids = Int[]
    for (node1, node2) in edges
        push!(
            not_equal_ids,
            add_invariant!(
                dag,
                RelationalInvariant{IntDecisionValue,NeOp}();
                variable_parent_indexes = [node1, node2],
                name = "not_equal_$(node1)_$(node2)",
                using_cp = true,
            ),
        )
    end

    constraint_id = add_invariant!(dag, StaticConstraintInvariant(α); invariant_parent_indexes = not_equal_ids)

    max_id = add_invariant!(
        dag,
        MaximumInvariant(max_color);
        variable_parent_indexes = collect(1:n_nodes),
        name = "number_of_colors",
    )
    obj_id = add_invariant!(dag, ObjectiveInvariant(); invariant_parent_indexes = [max_id])

    add_invariant!(dag, AggregatorInvariant(); invariant_parent_indexes = [obj_id, constraint_id])

    return dag
end

@testitem "Test graph coloring eval" begin
    dag = JuLS.create_graph_coloring_dag(3, [(1, 2), (2, 3), (3, 1)], 3)

    var1, var2, var3 = [JuLS.DecisionVariable(i, JuLS.IntDecisionValue(1)) for i = 1:3]
    JuLS.init!(dag, JuLS.DecisionVariablesArray([var1, var2, var3]))

    move = JuLS.Move([var2, var3], [JuLS.IntDecisionValue(2), JuLS.IntDecisionValue(3)])

    evaluated_move = JuLS.eval(dag, move)

    @test JuLS.delta_obj(evaluated_move) == 3 - (1 + 3 * 10) # New = 3 colors 0 violation, Old = 1 color 3 violations
    @test JuLS.isfeasible(evaluated_move)

    move = JuLS.Move([var2, var3], [JuLS.IntDecisionValue(2), JuLS.IntDecisionValue(2)])
    evaluated_move = JuLS.eval(dag, move)

    @test JuLS.delta_obj(evaluated_move) == (2 + 1 * 10) - (1 + 3 * 10) # New = 2 colors 1 violation, Old = 1 color 3 violations
    @test !JuLS.isfeasible(evaluated_move)
end

@testitem "Test graph coloring commit!" begin
    dag = JuLS.create_graph_coloring_dag(3, [(1, 2), (2, 3), (3, 1)], 3)

    var1, var2, var3 = [JuLS.DecisionVariable(i, JuLS.IntDecisionValue(1)) for i = 1:3]
    JuLS.init!(dag, JuLS.DecisionVariablesArray([var1, var2, var3]))

    move = JuLS.Move([var2, var3], [JuLS.IntDecisionValue(2), JuLS.IntDecisionValue(3)])
    JuLS.commit!(dag, JuLS.eval(dag, move))

    var1, var2, var3 = [JuLS.DecisionVariable(i, JuLS.IntDecisionValue(i)) for i = 1:3]

    evaluated_move = JuLS.eval(dag, JuLS.Move([var2, var3], [JuLS.IntDecisionValue(1), JuLS.IntDecisionValue(2)]))

    @test JuLS.delta_obj(evaluated_move) == (2 + 1 * 10) - (3)
    @test !JuLS.isfeasible(evaluated_move)
end

@testitem "Graph coloring full eval" begin
    dag = JuLS.create_graph_coloring_dag(3, [(1, 2), (2, 3), (3, 1)], 3)

    var1, var2, var3, var4 = [JuLS.DecisionVariable(i, JuLS.IntDecisionValue(1)) for i = 1:4]
    JuLS.init!(dag, JuLS.DecisionVariablesArray([var1, var2, var3]))

    solution1 = JuLS.Solution(JuLS.eval(dag, JuLS.DecisionVariablesArray(JuLS.DecisionVariable[var1, var2, var3])))

    @test solution1.values == [JuLS.IntDecisionValue(1), JuLS.IntDecisionValue(1), JuLS.IntDecisionValue(1)]
    @test solution1.objective == 3 * 10 + 1
    @test !solution1.feasible

    var2 = JuLS.DecisionVariable(2, JuLS.IntDecisionValue(2))
    var3 = JuLS.DecisionVariable(3, JuLS.IntDecisionValue(3))
    solution2 = JuLS.Solution(JuLS.eval(dag, JuLS.DecisionVariablesArray(JuLS.DecisionVariable[var1, var2, var3])))

    @test solution2.values == [JuLS.IntDecisionValue(1), JuLS.IntDecisionValue(2), JuLS.IntDecisionValue(3)]
    @test solution2.objective == 3
    @test solution2.feasible
end