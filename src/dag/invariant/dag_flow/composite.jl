# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    CompositeInvariant <: Invariant

A composite invariant that combines a simple chain of invariants into a single unit.

# Fields
- `invariants::Vector{Invariant}`: A vector of individual invariants.
- `names::Vector{Union{Nothing,String}}`: A vector of names corresponding to each invariant. 
   Can be `nothing` if no name is provided.

# Constructors
    CompositeInvariant(invariants::Vector{<:Invariant}, names::Vector{<:Union{Nothing,String}})
    CompositeInvariant(invariants::Vector{<:Invariant})

Creates a new `CompositeInvariant`. If names are not provided, they default to `nothing`.

# Throws
- `AssertionError`: If `invariants` is empty or if the length of `invariants` and `names` don't match.
   
# Notes
The CompositeInvariant allows grouping multiple invariants together, which can be useful for creating more complex invariant structures or for organizational purposes.
When evaluating, committing, initializing, or outputting, the composite invariant applies the operation to each of its contained invariants in sequence. 
"""
struct CompositeInvariant <: Invariant
    invariants::Vector{Invariant}
    names::Vector{Union{Nothing,String}}

    function CompositeInvariant(invariants::Vector{<:Invariant}, names::Vector{<:Union{Nothing,String}})
        @assert !isempty(invariants) "A composite invariant must have at least one invariant."
        @assert length(invariants) == length(names) "A composite invariant must have as many names as its number of invariants."

        new(invariants, names)
    end
end
CompositeInvariant(invariants::Vector{<:Invariant}) =
    CompositeInvariant(invariants, [nothing for _ = 1:length(invariants)])

function eval(composite_invariant::CompositeInvariant, message::DAGMessage)
    result = message

    for invariant in composite_invariant.invariants
        if iszero(result)
            return NoMessage()
        end
        result = eval(invariant, _init_message(InputType(invariant), result))
    end

    return result
end

function commit!(composite_invariant::CompositeInvariant, message::DAGMessage)
    result = message

    for invariant in composite_invariant.invariants
        if iszero(result)
            return NoMessage()
        end
        new_result = eval(invariant, _init_message(InputType(invariant), result))
        commit!(invariant, _init_message(InputType(invariant), result))
        result = new_result
    end
end

function init!(composite_invariant::CompositeInvariant, message::DAGMessage)
    result = message

    for invariant in composite_invariant.invariants
        if iszero(result)
            return NoMessage()
        end
        result = init!(invariant, _init_message(InputType(invariant), result))
    end

    return result
end

function output(
    composite_invariant::CompositeInvariant,
    message::OutputMessage,
    output_path::String,
    helper::AbstractDAGHelper;
    name::Union{String,Nothing} = nothing,
)
    result = message

    for (i, invariant) in enumerate(composite_invariant.invariants)
        if iszero(result)
            return NoMessage()
        end
        result = output(
            invariant,
            _init_message(InputType(invariant), result),
            output_path,
            helper;
            name = composite_invariant.names[i],
        )
    end

    return result
end

@testitem "testing constructors" begin
    struct MockInvariant <: JuLS.Invariant end

    @test_throws AssertionError("A composite invariant must have at least one invariant.") JuLS.CompositeInvariant(
        MockInvariant[],
    )
    @test_throws AssertionError("A composite invariant must have as many names as its number of invariants.") JuLS.CompositeInvariant(
        [MockInvariant()],
        ["a name", "second name"],
    )

    invariant = JuLS.CompositeInvariant([MockInvariant(), MockInvariant()])

    @test all(isnothing.(invariant.names))
end

@testitem "testing composite invariant eval" begin
    struct MockInvariant <: JuLS.Invariant end
    JuLS.InputType(::MockInvariant) = JuLS.SingleType()

    JuLS.eval(::MockInvariant, m::JuLS.FloatDelta) = m + JuLS.FloatDelta(1)

    invariant = JuLS.CompositeInvariant([MockInvariant(), MockInvariant()])

    @test JuLS.eval(invariant, JuLS.FloatDelta(1)) == JuLS.FloatDelta(3)
end

@testitem "testing composite invariant eval with default input type" begin
    struct MockInvariant <: JuLS.Invariant end

    JuLS.eval(::MockInvariant, m::JuLS.FloatDelta) = m + JuLS.FloatDelta(1)

    invariant = JuLS.CompositeInvariant([MockInvariant(), MockInvariant()])

    @test_throws MethodError JuLS.eval(invariant, JuLS.FloatDelta(1)) == JuLS.FloatDelta(3)
end

@testitem "testing composite invariant eval with zero message" begin
    mutable struct MockInvariant <: JuLS.Invariant
        counter::Int
    end
    JuLS.InputType(::MockInvariant) = JuLS.SingleType()

    JuLS.eval(inv::MockInvariant, ::JuLS.FloatDelta) = (inv.counter += 1; JuLS.FloatDelta(0))

    invariant = JuLS.CompositeInvariant([MockInvariant(0), MockInvariant(0)])

    @test JuLS.eval(invariant, JuLS.FloatDelta(1)) == JuLS.NoMessage()
    @test invariant.invariants[1].counter == 1
    @test invariant.invariants[2].counter == 0

    invariant = JuLS.CompositeInvariant([MockInvariant(0), MockInvariant(0)])

    @test JuLS.eval(invariant, JuLS.FloatDelta(0)) == JuLS.NoMessage()
    @test invariant.invariants[1].counter == 0
    @test invariant.invariants[2].counter == 0
end

@testitem "testing composite invariant commit!" begin
    mutable struct MockInvariant <: JuLS.Invariant
        a::JuLS.FloatDelta
    end
    JuLS.InputType(::MockInvariant) = JuLS.SingleType()

    JuLS.eval(::MockInvariant, m::JuLS.FloatDelta) = (m + JuLS.FloatDelta(1))
    JuLS.commit!(inv::MockInvariant, m::JuLS.FloatDelta) = (inv.a += m; nothing)

    invariant = JuLS.CompositeInvariant([MockInvariant(JuLS.FloatDelta(0)), MockInvariant(JuLS.FloatDelta(0))])

    JuLS.commit!(invariant, JuLS.FloatDelta(1)) == JuLS.FloatDelta(3)

    @test invariant.invariants[1].a == JuLS.FloatDelta(1)
    @test invariant.invariants[2].a == JuLS.FloatDelta(2)
end

@testitem "testing composite invariant commit! with complex stateful logic" begin
    mutable struct MockInvariant <: JuLS.Invariant
        a::JuLS.FloatDelta
    end
    JuLS.InputType(::MockInvariant) = JuLS.SingleType()

    JuLS.eval(inv::MockInvariant, m::JuLS.FloatDelta) = (m - inv.a)
    JuLS.commit!(inv::MockInvariant, m::JuLS.FloatDelta) = (inv.a = m; nothing)

    invariant = JuLS.CompositeInvariant([MockInvariant(JuLS.FloatDelta(0)), MockInvariant(JuLS.FloatDelta(1))])

    JuLS.commit!(invariant, JuLS.FloatDelta(1)) == JuLS.FloatDelta(0)

    @test invariant.invariants[1].a == JuLS.FloatDelta(1)
    @test invariant.invariants[2].a == JuLS.FloatDelta(1)
end

@testitem "testing composite invariant init!" begin
    mutable struct MockInvariant <: JuLS.Invariant
        a::JuLS.FloatFullMessage
    end
    JuLS.InputType(::MockInvariant) = JuLS.SingleType()

    JuLS.eval(::MockInvariant, m::JuLS.FloatFullMessage) = (m + JuLS.FloatFullMessage(1))
    JuLS.init!(inv::MockInvariant, m::JuLS.FloatFullMessage) = (inv.a = m; JuLS.eval(inv, m))

    invariant =
        JuLS.CompositeInvariant([MockInvariant(JuLS.FloatFullMessage(0)), MockInvariant(JuLS.FloatFullMessage(0))])

    JuLS.init!(invariant, JuLS.FloatFullMessage(0)) == JuLS.FloatFullMessage(2)

    @test invariant.invariants[1].a == JuLS.FloatFullMessage(0)
    @test invariant.invariants[2].a == JuLS.FloatFullMessage(1)
end

@testitem "testing composite invariant output" begin
    struct MockInvariant <: JuLS.Invariant end
    JuLS.InputType(::MockInvariant) = JuLS.SingleType()

    JuLS.eval(::MockInvariant, m::JuLS.FloatFullMessage) = (m + JuLS.FloatFullMessage(1))

    invariant = JuLS.CompositeInvariant([MockInvariant(), MockInvariant()])

    input = JuLS.OutputMessage(JuLS.FloatFullMessage(0), JuLS.FloatFullMessage(1))

    output = JuLS.output(invariant, input, joinpath(JuLS.PROJECT_ROOT, "whatever_path"), JuLS.NoHelper())

    @test output == JuLS.OutputMessage(JuLS.FloatFullMessage(2), JuLS.FloatFullMessage(3))
end
