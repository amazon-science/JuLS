# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

using DataStructures

"""
    abstract type AbstractStateEntry end

Any object that can be stacked into the trailer must be a subtype of this.
"""
abstract type AbstractStateEntry end

Base.show(io::IO, se::AbstractStateEntry) = write(io, "AbstractStateEntry")

"""
    struct Trailer

The trailer is the structure which makes it possible to memorize the previous State of our model 
during the search. It makes it possible to handle the backtrack.
"""
mutable struct Trailer
    current::Stack{AbstractStateEntry}
    prior::Stack{Stack{AbstractStateEntry}}
    Trailer() = new(Stack{AbstractStateEntry}(), Stack{Stack{AbstractStateEntry}}())
end

Base.show(io::IO, tr::Trailer) = write(io, "Trailer")


"""
    StateObject{T}(value::T, trailer::Trailer)

A reversible object of value `value` that has a type `T`, storing its modification into `trailer`.
"""
mutable struct StateObject{T}
    value::T
    trailer::Trailer
end

Base.show(io::IO, so::StateObject{T}) where {T} = write(io, "StateObject{", string(T), "}: ", string(so.value))


"""
    StateEntry{T}(value::T, object::StateObject{T})

An entry that can be stacked in the trailer, containing the former `value of the object, and a reference to
the `object` so that it can be restored by the trailer.
"""
struct StateEntry{T} <: AbstractStateEntry
    value::T
    object::StateObject{T}
end


"""
    trail!(var::StateObject{T})

Store the current value of `var` into its trailer.
"""
function trail!(var::StateObject)
    push!(var.trailer.current, StateEntry(var.value, var))
end

"""
    set_value!(var::StateObject{T}, value::T) where {T}

Change the value of `var`, replacing it with `value`, and if needed, store the
former value into `var`'s trailer.
"""
function set_value!(var::StateObject{T}, value::T) where {T}
    if (value != var.value)
        trail!(var)
        var.value = value
    end
    return var.value
end

"""
    save_state!(trailer::Trailer)

Store the current state into the trailer, replacing the current stack with an empty one.
"""
function save_state!(trailer::Trailer)
    push!(trailer.prior, trailer.current)
    trailer.current = Stack{AbstractStateEntry}()
    nothing
end

"""
    restore_state!(trailer::Trailer)

Iterate over the last state to restore every former value, used to backtrack every change 
made after the last call to [`save_state!`](@ref).
"""
function restore_state!(trailer::Trailer)
    for se in trailer.current
        se.object.value = se.value
    end

    if isempty(trailer.prior)
        trailer.current = Stack{AbstractStateEntry}()
    else
        trailer.current = pop!(trailer.prior)
    end
    nothing
end

"""
    restore_initial_state!(trailer::Trailer)

Restore every linked object to its initial state. Basically call [`restore_state!`](@ref) until not possible.
"""
function restore_initial_state!(trailer::Trailer)
    while !isempty(trailer.prior)
        restore_state!(trailer)
    end
    restore_state!(trailer)
end

function Base.empty!(trailer::Trailer)
    empty!(trailer.prior)
    trailer.current = Stack{AbstractStateEntry}()
end

@testitem "StateObject{Int}()" begin
    trailer = JuLS.Trailer()
    reversibleInt = JuLS.StateObject{Int}(3, trailer)

    @test reversibleInt.value == 3
    @test reversibleInt.trailer == trailer
end

@testitem "StateObject{Bool}()" begin
    trailer = JuLS.Trailer()
    reversibleInt = JuLS.StateObject{Bool}(true, trailer)

    @test reversibleInt.value == true
    @test reversibleInt.trailer == trailer
end

@testitem "trail!()" begin
    trailer = JuLS.Trailer()
    reversibleInt = JuLS.StateObject{Int}(3, trailer)

    JuLS.trail!(reversibleInt)

    @test length(trailer.current) == 1

    se = first(trailer.current)

    @test se.object == reversibleInt
    @test se.value == 3
end

@testitem "set_value!()" begin
    trailer = JuLS.Trailer()
    reversibleInt = JuLS.StateObject{Int}(3, trailer)

    JuLS.set_value!(reversibleInt, 3)
    @test length(trailer.current) == 0
    @test reversibleInt.value == 3

    JuLS.set_value!(reversibleInt, 5)
    @test length(trailer.current) == 1
    @test reversibleInt.value == 5

    se = first(trailer.current)
    @test se.value == 3

end

@testitem "save_state!()" begin
    trailer = JuLS.Trailer()
    reversibleInt = JuLS.StateObject{Int}(3, trailer)

    current = trailer.current

    JuLS.set_value!(reversibleInt, 5)
    JuLS.save_state!(trailer)

    @test first(trailer.prior) == current
    @test isempty(trailer.current)
end

@testitem "restore_state!()" begin
    trailer = JuLS.Trailer()
    reversibleInt = JuLS.StateObject{Int}(3, trailer)

    current = trailer.current

    JuLS.set_value!(reversibleInt, 5)
    JuLS.save_state!(trailer)
    JuLS.set_value!(reversibleInt, 8)

    @test reversibleInt.value == 8

    JuLS.restore_state!(trailer)

    @test reversibleInt.value == 5

    JuLS.restore_state!(trailer)

    @test reversibleInt.value == 3
end

@testitem "restore_initial_state!()" begin
    trailer = JuLS.Trailer()
    reversibleInt = JuLS.StateObject{Int}(3, trailer)

    JuLS.save_state!(trailer)
    JuLS.set_value!(reversibleInt, 4)
    JuLS.save_state!(trailer)
    JuLS.set_value!(reversibleInt, 5)
    JuLS.save_state!(trailer)
    JuLS.set_value!(reversibleInt, 6)
    JuLS.save_state!(trailer)
    JuLS.set_value!(reversibleInt, 7)

    JuLS.restore_initial_state!(trailer)

    @test reversibleInt.value == 3
end

@testitem "empty!(::Trailer)" begin
    trailer = JuLS.Trailer()

    state = JuLS.StateObject{Int}(3, trailer)

    reversibleInt = JuLS.StateObject{Int}(3, trailer)

    JuLS.save_state!(trailer)
    JuLS.set_value!(reversibleInt, 4)
    JuLS.save_state!(trailer)
    JuLS.set_value!(reversibleInt, 5)
    JuLS.save_state!(trailer)
    JuLS.restore_state!(trailer)
    JuLS.set_value!(reversibleInt, 6)
    JuLS.save_state!(trailer)
    JuLS.set_value!(reversibleInt, 7)

    JuLS.empty!(trailer)

    JuLS.restore_initial_state!(trailer)

    @test reversibleInt.value == 7
    @test isempty(trailer.prior)
    @test isempty(trailer.current)
end