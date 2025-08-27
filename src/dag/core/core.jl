# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct DAG <: MoveEvaluator

Core data structure representing an optimization problem as a Directed Acyclic Graph (DAG). 
An invariant represents an intermediate relationship between variables.
We represent these relationships as a Directed Acyclic Graph (DAG). This representation
allows for cheap evaluations of local moves.

# Fields
- `_invariants::Vector{Invariant}`: Problem invariants (nodes of the DAG)
- `_names::Vector{Union{Nothing,String}}`: Optional names for invariants
- `_using_cp::BitVector`: Flags for constraint programming usage per invariant
- `_adjacency_matrix::AdjacencyMatrix`: Graph structure representation
- `_var_to_first_invariants::Vector{Int}`: Maps variables to their first dependent invariants
- `_early_stop_threshold::Float64`: Threshold for early termination of move evaluation
- `_helper::AbstractDAGHelper`: Problem-specific helper object
- `_is_init::Bool`: Initialization status flag
"""
mutable struct DAG <: MoveEvaluator
    _invariants::Vector{Invariant}
    _names::Vector{Union{Nothing,String}}
    _using_cp::BitVector
    _adjacency_matrix::AdjacencyMatrix
    _var_to_first_invariants::Vector{Int}
    _early_stop_threshold::Float64
    _helper::AbstractDAGHelper
    _is_init::Bool
end

include("messages.jl")
include("delta.jl")
include("run_mode.jl")
include("delta_run.jl")
include("full_run.jl")
include("init_run.jl")
include("output_run.jl")

const EARLY_STOP_CONSTRAINT_THRESHOLD = 0.1
struct NoHelper <: AbstractDAGHelper end

"""
    DAG(n_variables::Int; 
        helper::AbstractDAGHelper = NoHelper(),
        early_stop_threshold::Float64 = EARLY_STOP_CONSTRAINT_THRESHOLD)

Constructs a new DAG with specified number of decision variables.

# Arguments
- `n_variables::Int`: Number of decision variables
- `helper::AbstractDAGHelper`: Problem-specific helper (default: NoHelper)
- `early_stop_threshold::Float64`: Threshold for early termination
"""
function DAG(
    n_variables::Int;
    helper::AbstractDAGHelper = NoHelper(),
    early_stop_threshold::Float64 = EARLY_STOP_CONSTRAINT_THRESHOLD,
)
    adj = AdjacencyMatrix()
    DAG(
        [_DecisionVariableInvariant() for _ = 1:n_variables],
        [nothing for _ = 1:n_variables],
        trues(n_variables),
        adj,
        [add_node!(adj) for _ = 1:n_variables],
        early_stop_threshold,
        helper,
        false,
    )
end

Base.length(dag::DAG) = length(dag._invariants)
invariants(dag::DAG) = dag._invariants
invariant(dag::DAG, invariant_id::Int) = dag._invariants[invariant_id]
invariant_name(dag::DAG, invariant_id::Int) = dag._names[invariant_id]
invariant_using_cp(dag::DAG, invariant_id::Int) = dag._using_cp[invariant_id]
early_stop_threshold(dag::DAG) = dag._early_stop_threshold
early_stop_threshold!(dag::DAG, threshold::Float64) = dag._early_stop_threshold = threshold
helper(dag::DAG) = dag._helper

struct _ResultInvariant <: Invariant end
struct _DecisionVariableInvariant <: Invariant end
InputType(::_ResultInvariant) = SingleType()
eval(::_DecisionVariableInvariant, message::DAGMessage) = message
eval(::_ResultInvariant, ::DAGMessage) = NoMessage()
commit!(::_DecisionVariableInvariant, ::DAGMessage) = nothing
commit!(::_ResultInvariant, ::DAGMessage) = nothing

"""
    isinit(::DAG)

Tell whether a DAG has been `init!` already.
When a DAG has been init, it's not possible to add invariants anymore.

Note that it could be possible to bypass this by calling methods on dag._adjacency_matrix. 
This would lead to unexpected and unfixable behaviours.
"""
isinit(dag::DAG) = dag._is_init


"""
    init!(dag::DAG)
    init!(dag::DAG, variables::DecisionVariablesArray)

Initializes DAG structure for use.

# Process
1. Validates DAG structure
2. Adds a ResultInvariant as last node
3. Applies topological sorting
4. Initializes invariant state with decision variable current values.

# Errors
- If DAG already initialized
- If DAG contains cycles
- If DAG structure invalid, i.e. the DAG must have exactly one last node and no orphan invariants (except the ones representing decision variables)
"""
function init!(dag::DAG)
    if isinit(dag)
        # No point in instantiating a DAG that is already.
        return
    end
    if length(dag) == 0
        @warn "Impossible to instantiate an empty DAG. Not proceeding."
        return
    end

    # The DAG must have exactly one last node.
    last_nodes = findall(x -> x == 0, children_degrees(dag._adjacency_matrix))
    if length(last_nodes) != 1
        @error "The DAG must have exactly one last node (defined as a node without children)."
        error()
    end
    orphan_invariants = findall(x -> x == 0, parents_degrees(dag._adjacency_matrix))
    if any(typeof.(dag._invariants[orphan_invariants]) .!= _DecisionVariableInvariant)
        @error "Every invariant must have dependencies on a variable or another invariant."
        error()
    end
    if length(last_nodes) == 0
        @error "The DAG must contain at least one node that has a decision variable as a parent."
        error()
    end

    add_invariant!(dag, _ResultInvariant(), [last_nodes[1]])
    ranks = sort_dag!(dag)
    dag._var_to_first_invariants .= ranks[dag._var_to_first_invariants] # Since the invariants are resorted, we need to update the indexes of the decision variable dependencies

    dag._is_init = true

    @info "The DAG structure is instantiated."
end

function init!(dag::DAG, variables::DecisionVariablesArray)
    init!(dag)
    run_dag!(InitRun(variables, dag), dag)
    @info "The DAG invariants are instantiated."
end

first_node(dag::DAG) = invariant(dag, first_node_id(dag))
second_node(dag::DAG) = invariant(dag, second_node_id(dag))
last_node(dag::DAG) = invariant(dag, last_node_id(dag))

first_node_id(dag::DAG) = 1
second_node_id(dag::DAG) = 2
last_node_id(dag::DAG) = length(dag._invariants)

"""
    add_invariant!(::DAG, ::Invariant; invariant_parent_indexes::Vector{Int} = Int[], variable_parent_indexes::Vector{Int} = Int[], name::Union{String, Nothing} = nothing)

Add an invariant to the DAG. It will add it to the AdjacencyMatric of the DAG as well.
It's possible to optionally pass a name to this new invariant.

Note that you need to call the `init!` method before using the DAG whenever you add an invariant.

# Arguments
- `dag::DAG`: The DAG. 
- `invariant::Invariant`: The invariant to add. 


# Optional arguments
- `invariant_parent_indexes::Vector{Int}`: The invariant parent indexes of the new invariant: the other invariants this invariant will need inputs from.
- `variable_parent_indexes::Vector{Int}`: The variable parent indexes of the new invariant: the variables that the invariant directly depend on. This means the invariant will receive some `SingleVariableMoveDelta` directly for any variables that was changed (when in DeltaRun).
- `name::Union{String,Nothing} = nothing`: The name of the invariant. 
- `using_cp`: Whether to use constraint programming

Important: Each invariant requires at least one parent connection:
- Must specify either invariant_parent_indexes or variable_parent_indexes
- Orphan invariants (no parents) will cause init! to fail
- Exception: Only _DecisionVariableInvariant can exist without parents
This maintains DAG connectivity and ensures valid evaluation paths.
"""
add_invariant!(
    dag::DAG,
    invariant::Invariant;
    invariant_parent_indexes::Vector{Int} = Int[],
    variable_parent_indexes::Vector{Int} = Int[],
    name::Union{String,Nothing} = nothing,
    using_cp::Bool = false,
) = add_invariant!(
    dag,
    invariant,
    vcat(invariant_parent_indexes, dag._var_to_first_invariants[variable_parent_indexes]);
    name,
    using_cp,
)
function add_invariant!(
    dag::DAG,
    invariant::Invariant,
    parent_indexes::Vector{Int};
    name::Union{String,Nothing} = nothing,
    using_cp::Bool = false,
)
    if isinit(dag)
        @warn "Impossible to add an invariant to a DAG for which `init!` was called. Not proceeding."
        return
    end
    push!(dag._invariants, invariant)
    push!(dag._names, name)
    push!(dag._using_cp, using_cp)

    invariant_index = add_node!(dag._adjacency_matrix)
    for parent_index in parent_indexes
        add_edge!(dag, parent_index, invariant_index)
    end

    return invariant_index
end
add_edge!(dag::DAG, parent_index::Int, child_index::Int) = add_edge!(dag._adjacency_matrix, parent_index, child_index)

"""
    sort_dag!(dag::DAG)

Sort the DAG. 
It proceeds in two steps. First it computes a topoligical ordering of the dag using Kahn's algorithm.
Then, it rearranges the invariant, name and using_cp vector and adjacency matrix accordingly.

# Arguments
- `dag::DAG`: The DAG. 
"""
function sort_dag!(dag::DAG)
    ordered_invariant_ids, ranks = _rank_invariants!(dag)
    invariants = copy(dag._invariants)
    parent_adj_matrix = copy(dag._adjacency_matrix._parent_adjacency_matrix)
    children_adj_matrix = copy(dag._adjacency_matrix._children_adjacency_matrix)
    names, using_cp = copy(dag._names), copy(dag._using_cp)

    for i in eachindex(dag._invariants)
        dag._invariants[i] = invariants[ordered_invariant_ids[i]]
        dag._adjacency_matrix._children_adjacency_matrix[i] =
            [ranks[x] for x in children_adj_matrix[ordered_invariant_ids[i]]]
        dag._adjacency_matrix._parent_adjacency_matrix[i] =
            [ranks[x] for x in parent_adj_matrix[ordered_invariant_ids[i]]]
        dag._names[i], dag._using_cp[i] = names[ordered_invariant_ids[i]], using_cp[ordered_invariant_ids[i]]
    end
    return ranks
end

"""
    _rank_invariants!(dag::DAG)

Internal function that implements Kahn's algorithm for topological sorting of the DAG.

# Algorithm (Kahn's algorithm)
1. Identify nodes with no incoming edges (in-degree = 0)
2. While there are nodes with in-degree 0:
   a. Remove a node with in-degree 0
   b. Add it to the sorted list
   c. Decrement in-degree of its neighbors
   d. If a neighbor's in-degree becomes 0, add it to the queue
3. If all nodes are visited, return the sorted order
   Otherwise, the graph has a cycle

# Purpose
- Ensures invariants are evaluated in the correct order
- Detects cycles in the graph structure

# Errors
- Raises an error if a cycle is detected in the DAG
"""
function _rank_invariants!(dag::DAG)
    sorted_nodes = []
    ranks = Vector{Int}(undef, length(dag._invariants))

    n = length(dag._invariants)

    in_degrees = parents_degrees(dag._adjacency_matrix)

    zero_nodes = findall(x -> x == 0, in_degrees)

    append!(sorted_nodes, zero_nodes)

    while !isempty(zero_nodes)
        node = pop!(zero_nodes)
        for neighbour_node in children(dag._adjacency_matrix, node)
            in_degrees[neighbour_node] -= 1
            if in_degrees[neighbour_node] == 0
                append!(sorted_nodes, neighbour_node)
                append!(zero_nodes, neighbour_node)
            end
        end
    end

    if length(sorted_nodes) != length(dag._invariants)
        @error "The DAG contains cycle, hence it's not a DAG."
        error()
    end

    for i = 1:n
        ranks[sorted_nodes[i]] = i
    end

    return sorted_nodes, ranks
end

@testitem "Testing DAG constructor" begin
    dag = JuLS.DAG(1)

    @test dag._invariants == [JuLS._DecisionVariableInvariant()]
    @test dag._adjacency_matrix._children_adjacency_matrix == [[]]
    @test dag._adjacency_matrix._parent_adjacency_matrix == [[]]
    @test dag._names == [nothing]
    @test dag._var_to_first_invariants == [1]
    @test !dag._is_init
    @test dag._early_stop_threshold == JuLS.EARLY_STOP_CONSTRAINT_THRESHOLD
end

@testitem "Testing adding invariant" begin
    struct MockInvariant <: JuLS.Invariant end

    invariant1 = MockInvariant()
    invariant2 = MockInvariant()
    invariant3 = MockInvariant()
    invariant4 = MockInvariant()

    dag = JuLS.DAG(1) # picture of the test DAG below 😀

    #            var1
    #             |
    #             |
    #        invariant1
    #           /  \
    #          /    \
    #         /      \
    # invariant2    invariant3
    #         \      /
    #          \    /
    #           \  /
    #        invariant4

    JuLS.add_invariant!(dag, invariant1)

    @test dag._invariants == [JuLS._DecisionVariableInvariant(), invariant1]
    @test dag._adjacency_matrix._children_adjacency_matrix == [[], []]
    @test dag._adjacency_matrix._parent_adjacency_matrix == [[], []]

    JuLS.add_invariant!(dag, invariant2; invariant_parent_indexes = [1])
    JuLS.add_invariant!(dag, invariant3; invariant_parent_indexes = [1])

    @test dag._invariants == [JuLS._DecisionVariableInvariant(), invariant1, invariant2, invariant3]
    @test dag._adjacency_matrix._children_adjacency_matrix == [[3, 4], [], [], []]
    @test dag._adjacency_matrix._parent_adjacency_matrix == [[], [], [1], [1]]

    JuLS.add_invariant!(dag, invariant4; invariant_parent_indexes = [2, 3])

    @test length(dag) == 5
    @test dag._invariants == [JuLS._DecisionVariableInvariant(), invariant4, invariant3, invariant2, invariant1]
    @test dag._adjacency_matrix._children_adjacency_matrix == [[3, 4], [5], [5], [], []]
    @test dag._adjacency_matrix._parent_adjacency_matrix == [[], [], [1], [1], [2, 3]]
end

@testitem "Testing adding invariant names" begin
    struct MockInvariant <: JuLS.Invariant end

    invariant1 = MockInvariant()
    invariant2 = MockInvariant()
    invariant3 = MockInvariant()
    invariant4 = MockInvariant()

    dag = JuLS.DAG(1) # picture of the test DAG below 😀

    #            var1
    #             |
    #             |
    #        invariant1
    #           /  \
    #          /    \
    #         /      \
    # invariant2    invariant3
    #         \      /
    #          \    /
    #           \  /
    #        invariant4

    invariant1_id = JuLS.add_invariant!(dag, invariant1; name = "invariant1", variable_parent_indexes = [1])
    invariant2_id =
        JuLS.add_invariant!(dag, invariant2; name = "invariant2", invariant_parent_indexes = [invariant1_id])
    invariant3_id =
        JuLS.add_invariant!(dag, invariant3; name = "invariant3", invariant_parent_indexes = [invariant1_id])
    invariant4_id = JuLS.add_invariant!(dag, invariant4; invariant_parent_indexes = [invariant2_id, invariant3_id])

    @test dag._names == [nothing, "invariant1", "invariant2", "invariant3", nothing]
    @test JuLS.invariant_name(dag, 1) === nothing
    @test JuLS.invariant_name(dag, 2) == "invariant1"
    @test JuLS.invariant_name(dag, 3) == "invariant2"
    @test JuLS.invariant_name(dag, 4) == "invariant3"
    @test JuLS.invariant_name(dag, 5) === nothing
end

@testitem "Test Kahn's algorithm" begin
    struct MockInvariant <: JuLS.Invariant end

    invariant1 = MockInvariant()
    invariant2 = MockInvariant()
    invariant3 = MockInvariant()
    invariant4 = MockInvariant()

    dag = JuLS.DAG(1) # picture of the test DAG below 😀

    #            var1
    #             |
    #             |
    #        invariant1
    #           /  \
    #          /    \
    #         /      \
    # invariant2    invariant3
    #         \      /
    #          \    /
    #           \  /
    #        invariant4

    invariant1_id = JuLS.add_invariant!(dag, invariant1; variable_parent_indexes = [1])
    invariant2_id = JuLS.add_invariant!(dag, invariant2; invariant_parent_indexes = [invariant1_id])
    invariant3_id = JuLS.add_invariant!(dag, invariant3; invariant_parent_indexes = [invariant1_id])
    invariant4_id = JuLS.add_invariant!(dag, invariant4; invariant_parent_indexes = [invariant2_id, invariant3_id])

    ordered_invariant_ids, ranks = JuLS._rank_invariants!(dag)

    @test ranks == [1, 2, 3, 4, 5]
    @test ordered_invariant_ids == [1, 2, 3, 4, 5]
end

@testitem "Rank adjacency_matrix" begin
    struct MockInvariant <: JuLS.Invariant end

    invariant1 = MockInvariant()
    invariant2 = MockInvariant()
    invariant3 = MockInvariant()
    invariant4 = MockInvariant()

    dag = JuLS.DAG(1) # picture of the test DAG below 😀

    #            var1
    #             |
    #             |
    #        invariant1
    #           /  \
    #          /    \
    #         /      \
    # invariant2    invariant3
    #         \      /
    #          \    /
    #           \  /
    #        invariant4

    invariant1_id = JuLS.add_invariant!(dag, invariant1; variable_parent_indexes = [1], name = "1", using_cp = true)
    invariant2_id = JuLS.add_invariant!(dag, invariant2; invariant_parent_indexes = [invariant1_id], name = "2")
    invariant3_id = JuLS.add_invariant!(dag, invariant3; invariant_parent_indexes = [invariant1_id], name = "3")
    invariant4_id =
        JuLS.add_invariant!(dag, invariant4; invariant_parent_indexes = [invariant2_id, invariant3_id], name = "4")

    ranks = JuLS.sort_dag!(dag)
    invariant1_id = findfirst(ranks .== invariant1_id)
    invariant2_id = findfirst(ranks .== invariant2_id)
    invariant3_id = findfirst(ranks .== invariant3_id)
    invariant4_id = findfirst(ranks .== invariant4_id)

    @test dag._names == [nothing, "1", "2", "3", "4"]
    @test dag._using_cp == BitVector([true, true, false, false, false])

    @test JuLS.children(dag._adjacency_matrix, invariant1_id) == [invariant2_id, invariant3_id]
    @test JuLS.children(dag._adjacency_matrix, invariant2_id) == [invariant4_id]
    @test JuLS.children(dag._adjacency_matrix, invariant3_id) == [invariant4_id]
    @test JuLS.children(dag._adjacency_matrix, invariant4_id) == []

    @test JuLS.parents(dag._adjacency_matrix, invariant1_id) == [1]
    @test JuLS.parents(dag._adjacency_matrix, invariant2_id) == [invariant1_id]
    @test JuLS.parents(dag._adjacency_matrix, invariant3_id) == [invariant1_id]
    @test JuLS.parents(dag._adjacency_matrix, invariant4_id) == [invariant2_id, invariant3_id]
end

@testitem "init dag" begin
    struct MockInvariant <: JuLS.Invariant end

    invariant1 = MockInvariant()
    invariant2 = MockInvariant()
    invariant3 = MockInvariant()
    invariant4 = MockInvariant()

    dag = JuLS.DAG(1) # picture of the test DAG below 😀

    #            var1
    #             |
    #             |
    #        invariant1
    #           /  \
    #          /    \
    #         /      \
    # invariant2    invariant3
    #         \      /
    #          \    /
    #           \  /
    #        invariant4

    invariant1_id = JuLS.add_invariant!(dag, invariant1; variable_parent_indexes = [1], name = "1", using_cp = true)
    invariant2_id = JuLS.add_invariant!(dag, invariant2; invariant_parent_indexes = [invariant1_id], name = "2")
    invariant3_id = JuLS.add_invariant!(dag, invariant3; invariant_parent_indexes = [invariant1_id], name = "3")
    invariant4_id =
        JuLS.add_invariant!(dag, invariant4; invariant_parent_indexes = [invariant2_id, invariant3_id], name = "4")

    @test length(dag) == 5
    @test dag._names == [nothing, "1", "2", "3", "4"]

    JuLS.init!(dag)

    @test length(dag) == 6
    @test dag._names == [nothing, "1", "2", "3", "4", nothing]

    @test JuLS.children(dag._adjacency_matrix, 1) == [2]
end

@testitem "init dag edge cases" begin
    struct MockInvariant <: JuLS.Invariant end

    invariant1 = MockInvariant()

    dag = JuLS.DAG(0)
    @test !JuLS.isinit(dag)

    @test_logs (:warn, "Impossible to instantiate an empty DAG. Not proceeding.") JuLS.init!(dag)
    JuLS.init!(dag)
    @test length(dag) == 0
    @test !JuLS.isinit(dag)

    dag = JuLS.DAG(1)
    @test length(dag) == 1

    JuLS.add_invariant!(dag, invariant1; name = "1")
    @test length(dag) == 2

    @test_logs (:error, "The DAG must have exactly one last node (defined as a node without children).") begin
        @test_throws ErrorException JuLS.init!(dag)
    end
    JuLS.add_invariant!(dag, MockInvariant(); variable_parent_indexes = [1])
    JuLS.add_edge!(dag, 3, 2)
    JuLS.init!(dag)
    @test length(dag) == 4
    @test JuLS.isinit(dag)

    @test_logs (:warn, "Impossible to add an invariant to a DAG for which `init!` was called. Not proceeding.") JuLS.add_invariant!(
        dag,
        invariant1;
        name = "1",
    )
end

@testitem "dag with cycles" begin
    struct MockInvariant <: JuLS.Invariant end

    invariant1 = MockInvariant()
    invariant2 = MockInvariant()

    dag = JuLS.DAG(1) # picture of the test DAG below 😀

    #  invariant1 -> invariant2 -> invariant1

    JuLS.add_invariant!(dag, invariant1)
    JuLS.add_invariant!(dag, invariant2; invariant_parent_indexes = [2])

    JuLS.add_edge!(dag, 3, 2)

    @test_throws ErrorException JuLS.sort_dag!(dag)
    @test_throws ErrorException JuLS.init!(dag)

    invariant1 = MockInvariant()
    invariant2 = MockInvariant()
    invariant3 = MockInvariant()

    dag = JuLS.DAG(1) # picture of the test DAG below 😀

    #  invariant1 -> invariant2 -> invariant3 -> invariant2

    JuLS.add_invariant!(dag, invariant1)
    JuLS.add_invariant!(dag, invariant2; invariant_parent_indexes = [2])
    JuLS.add_invariant!(dag, invariant3; invariant_parent_indexes = [3])

    JuLS.add_edge!(dag, 4, 3)

    @test_throws ErrorException JuLS.sort_dag!(dag)
    @test_throws ErrorException JuLS.init!(dag)
end


@testitem "dag with multiple first/last nodes" begin
    struct MockInvariant <: JuLS.Invariant end

    invariant1 = MockInvariant()
    invariant2 = MockInvariant()


    dag = JuLS.DAG(1) # picture of the test DAG below 😀

    #  invariant1      var1 
    #       \          /
    #        \        /
    #         \      /
    #          \    /
    #        invariant2

    invariant1_id = JuLS.add_invariant!(dag, invariant1)
    invariant2_id =
        JuLS.add_invariant!(dag, invariant2; variable_parent_indexes = [1], invariant_parent_indexes = [invariant1_id])

    @test JuLS.sort_dag!(dag) isa Any # checking that we can sort the dag without errors
    @test_throws ErrorException JuLS.init!(dag) # invariant 1 is orphan

    invariant2 = MockInvariant()
    invariant3 = MockInvariant()

    dag = JuLS.DAG(1) # picture of the test DAG below 😀

    #           var1
    #          /    \
    #         /      \
    #        /        \
    #       /          \
    #  invariant2   invariant3


    JuLS.add_invariant!(dag, invariant2; variable_parent_indexes = [1])
    JuLS.add_invariant!(dag, invariant3; variable_parent_indexes = [1])

    @test JuLS.sort_dag!(dag) isa Any # checking that we can sort the dag without errors
    @test_throws ErrorException JuLS.init!(dag) # more than 1 last node
end


@testitem "init dag with initialization of invariants" begin
    mutable struct MockInvariantInit2 <: JuLS.Invariant
        visited::Bool
    end
    JuLS.InputType(::MockInvariantInit2) = JuLS.SingleType()
    struct MockMessage <: JuLS.DAGMessage end
    JuLS.init!(inv::MockInvariantInit2, ::JuLS.SingleVariableMessage) = (inv.visited = false; MockMessage())
    JuLS.init!(inv::MockInvariantInit2, ::MockMessage) = (inv.visited = true; MockMessage())

    invariant1 = MockInvariantInit2(false)
    invariant2 = MockInvariantInit2(false)
    invariant3 = MockInvariantInit2(false)

    dag = JuLS.DAG(1)

    invariant1_id = JuLS.add_invariant!(dag, invariant1; name = "1", variable_parent_indexes = [1])
    invariant2_id = JuLS.add_invariant!(dag, invariant2; name = "2", invariant_parent_indexes = [invariant1_id])
    invariant3_id = JuLS.add_invariant!(dag, invariant3; name = "3", invariant_parent_indexes = [invariant2_id])

    JuLS.init!(dag, JuLS.DecisionVariablesArray([JuLS.DecisionVariable(1, JuLS.BinaryDecisionValue(true))]))

    # We check that every invariant was initialized with the right value
    @test !invariant1.visited
    @test invariant2.visited
    @test invariant3.visited
end

@testitem "early_stop_threshold!" begin
    dag = JuLS.DAG(2)
    @test dag._early_stop_threshold[] == JuLS.EARLY_STOP_CONSTRAINT_THRESHOLD
    JuLS.early_stop_threshold!(dag, 3.0)
    @test dag._early_stop_threshold[] == 3.0
    JuLS.early_stop_threshold!(dag, Inf)
    @test dag._early_stop_threshold[] == Inf
end
