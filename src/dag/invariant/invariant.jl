# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    abstract type Invariant end

Abstract type representing invariants in optimization problems. Each concrete invariant type must implement four core functions:

# Required Method Implementations
    
- eval(invariant::YourInvariant, delta::Delta)
- eval(invariant::YourInvariant, message::FullMessage)
- commit!(invariant::YourInvariant, delta::Delta) (except for stateless invariant)
- init!(invariant::YourInvariant, message::FullMessage) (except for stateless invariant)

1. Delta Evaluation:
   - eval(invariant, delta::Delta)
   - Purpose: Evaluates impact of changes without full recomputation
   - Called during optimization for move evaluation
   - Must be efficient as called frequently
   - Returns: Delta representing impact of changes

2. Full Evaluation:
   - eval(invariant, message::FullMessage)
   - Purpose: Evaluates a complete solution for the invariant
   - Used for validation and verification, must not use the invariant state !!!
   - Can be more computationally intensive

3. Delta Commit:
   - commit!(invariant, delta::Delta)
   - Purpose: Updates invariant's internal state
   - Called when accepting moves
   - No return value, modifies invariant state in-place

4. Initialization:
   - init!(invariant, message::FullMessage)
   - Purpose: Sets initial state of invariant
   - Called once during DAG InitRun
   - Must return value such as full message evaluation
"""


"""
    abstract type StatelessInvariant <: Invariant end

Invariant subtype without state. No need to commit! and init!
"""
abstract type StatelessInvariant <: Invariant end
commit!(::StatelessInvariant, ::DAGMessage) = nothing
"""
    abstract type SummableEvalInvariant <: Invariant end

Invariant subtype for which evaluating a vector is the sum of single evaluations.
"""
abstract type SummableEvalInvariant <: Invariant end
eval(invariant::SummableEvalInvariant, messages::DAGMessagesVector) = sum([eval(invariant, m) for m in messages])
function commit!(invariant::SummableEvalInvariant, messages::DAGMessagesVector)
    for m in messages
        commit!(invariant, m)
    end
end

"""
    abstract type SummableDeltaInvariant <: Invariant end

Invariant subtype for which evaluating a vector is the evaluation of the sum of messages.
"""
abstract type SummableDeltaInvariant <: Invariant end
eval(invariant::SummableDeltaInvariant, messages::DAGMessagesVector) = eval(invariant, sum(messages))
commit!(invariant::SummableDeltaInvariant, messages::DAGMessagesVector) = commit!(invariant, sum(messages))
init!(invariant::SummableDeltaInvariant, messages::DAGMessagesVector) = init!(invariant, sum(messages))

commit!(::Invariant, ::NoMessage) = nothing


include("arithmetic/arithmetic.jl")
include("boolean/boolean.jl")
include("dag_flow/dag_flow.jl")
include("alldifferent.jl")
include("among.jl")
include("comparator.jl")
include("consecutive.jl")
include("element.jl")
include("equal.jl")
include("maximum.jl")
include("min_distance.jl")
include("scalar_product.jl")


FeasibilityEvaluation(::Union{ComparatorInvariant,StaticConstraintInvariant}) = HardConstraint()

@testitem "hard constraints" begin
    @test JuLS.FeasibilityEvaluation(JuLS.ComparatorInvariant(10)) isa JuLS.HardConstraint
    @test JuLS.FeasibilityEvaluation(JuLS.StaticConstraintInvariant(10.0)) isa JuLS.HardConstraint
end
