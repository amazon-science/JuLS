# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    build!(invariant::Invariant, input_variables::Vector{CPVariable}, trailer::Trailer, id::Int)

Core function for translating DAG invariants into CPConstraint/CPVariable. 

# Arguments
- `invariant::Invariant`: The DAG invariant to translate
- `input_variables::Vector{CPVariable}`: CP variables representing invariant inputs
- `trailer::Trailer`: CP state management object
- `id::Int`: Unique identifier for created output CPVariable, same one than corresponding invariant id


# Returns
One of:
- `CPVariableMessage`: When creating a new CP variable
- `CPConstraintMessage`: When creating a CP constraint
- `IntermediateCPVariableMessage`: When creating both variable and constraint
- `NoMessage`: When no CP element needed
"""

include("among_up.jl")
include("element.jl")
include("is_different.jl")
include("notequal.jl")
include("or.jl")
include("sumlessthan.jl")
include("view.jl")

build!(args...) = NoMessage()

"""
    build!(invariant::CompositeInvariant,
           input_variables::Vector{CPVariable},
           trailer::Trailer,
           id::Int)

Builds CP elements for CompositeInvariant by delegating to component invariants.
"""
build!(invariant::CompositeInvariant, input_variables::Vector{CPVariable}, trailer::Trailer, id::Int) =
    build!(invariant.invariants..., input_variables, trailer, id)



@testitem "build!(::CompositeInvariant)" begin
    among = JuLS.AmongInvariant(JuLS.Interval(3, 7))
    comparator = JuLS.ComparatorInvariant(2)

    invariant = JuLS.CompositeInvariant([among, comparator])

    trailer = JuLS.Trailer()
    x = JuLS.CPVariable[JuLS.IntVariable(i, 2, 9, trailer) for i = 1:8]

    cp_message = JuLS.build!(invariant, x, trailer, 5)

    @test cp_message isa JuLS.CPConstraintMessage
    @test cp_message.constraint isa JuLS.AmongUp

    w_among = JuLS.WeightedAmongInvariant(JuLS.Interval(3, 7), [i for i = 1:8])
    invariant = JuLS.CompositeInvariant([w_among, comparator])

    cp_message = JuLS.build!(invariant, x, trailer, 5)

    @test cp_message == JuLS.NoMessage()
end