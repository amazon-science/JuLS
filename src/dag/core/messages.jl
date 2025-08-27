# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

abstract type DAGMessages <: DAGMessage end

struct NoMessage <: DAGMessage end
Base.iszero(::NoMessage) = true

"""
    DAGMessagesVector{T <: DAGMessage}

Represents a vector of DAGMessages, it's a useful encapsulation to make the DAG more type stable.
"""
struct DAGMessagesVector{T<:DAGMessage} <: DAGMessages
    messages::AbstractArray{<:DAGMessage}
end
DAGMessagesVector(T::Type{<:DAGMessage}) = DAGMessagesVector{T}(DAGMessage[])
DAGMessagesVector(T::Type{<:DAGMessage}, lazy_messages::AbstractArray{<:DAGMessage}) =
    DAGMessagesVector{T}(lazy_messages)
function DAGMessagesVector(lazy_messages::AbstractArray{<:DAGMessage})
    isempty(lazy_messages) && return NoMessage()
    _is_single_type(lazy_messages) || error("A DAGMessagesVector can only take one concrete type.")

    return DAGMessagesVector(typeof(first(lazy_messages)), lazy_messages)
end

Base.length(dag_messages::DAGMessagesVector) = length(dag_messages.messages)
Base.iterate(dag_messages::DAGMessagesVector, state = 1) = iterate(dag_messages.messages, state)
Base.getindex(dag_messages::DAGMessagesVector{T}, i::Int) where {T<:DAGMessage} = convert(T, dag_messages.messages[i])
Base.iszero(dag_messages::DAGMessagesVector) = iszero(dag_messages.messages)
Base.last(dag_messages::DAGMessagesVector) = last(dag_messages.messages)
Base.sum(dag_messages::DAGMessagesVector{T}) where {T<:DAGMessage} =
    isempty(dag_messages) ? zero(T) : sum(dag_messages.messages)

"""
    MultiTypedDAGMessages

Represents DAGMessages that can have multiple types, each type will be mapped to its corresponding DAGMessages
in the dict messages.
"""
struct MultiTypedDAGMessages{T<:DAGMessage} <: DAGMessages
    lazy_messages::AbstractArray{<:DAGMessage}
end
MultiTypedDAGMessages() = MultiTypedDAGMessages{DAGMessage}(DAGMessage[])
MultiTypedDAGMessages(T::Type{<:DAGMessage}, lazy_messages::AbstractArray{<:DAGMessage}) =
    MultiTypedDAGMessages{_super_type(T)}(lazy_messages)
MultiTypedDAGMessages(lazy_messages::AbstractArray{<:DAGMessage}) =
    MultiTypedDAGMessages(typejoin(typeof.(lazy_messages)...), lazy_messages)

_super_type(::Type{<:Delta}) = Delta
_super_type(::Type{<:FullMessage}) = FullMessage

all_messages(dag_messages::MultiTypedDAGMessages) = dag_messages.lazy_messages
Base.keys(dag_messages::MultiTypedDAGMessages) = type_set(all_messages(dag_messages))
Base.haskey(dag_messages::MultiTypedDAGMessages, T::Type) = T in keys(dag_messages)
Base.getindex(dag_messages::MultiTypedDAGMessages, T::Type) =
    DAGMessagesVector{T}(all_messages(dag_messages)[typeof.(all_messages(dag_messages)).==T])
Base.iszero(dag_messages::MultiTypedDAGMessages) = iszero(all_messages(dag_messages))


type_set(messages::AbstractArray{<:DAGMessage}) = Set(typeof.(messages))
_is_single_type(lazy_messages::AbstractArray{<:DAGMessage}) =
    isempty(lazy_messages) || all(typeof.(lazy_messages) .== typeof(first(lazy_messages)))

"""
    InputType

Abstract type defining how invariants handle input messages in the DAG.

# Subtypes
- `SingleType`: Accepts single message
- `VectorType`: Accepts vector of messages (default)
- `MultiType`: Accepts multiple message types
"""
abstract type InputType end
struct SingleType <: InputType end
struct VectorType <: InputType end
struct MultiType <: InputType end

InputType(::Invariant) = VectorType()

"""
    make_input_message!(
        invariant::Invariant,
        invariant_index::Int,
        input_messages::Vector{<:DAGMessage},
        new_message::DAGMessage
    )

Handles message creation and aggregation for invariant inputs.

# Arguments
- `invariant`: Target invariant
- `invariant_index`: Index of invariant in DAG
- `input_messages`: Current message buffer
- `new_message`: Message to add

# Behavior
1. If input slot empty: Creates new message container based on InputType
2. If input exists: Appends new message to existing container
3. Handles NoMessage cases
"""
function make_input_message!(
    invariant::Invariant,
    invariant_index::Int,
    input_messages::Vector{<:DAGMessage},
    new_message::DAGMessage,
)
    if isassigned(input_messages, invariant_index) && input_messages[invariant_index] != NoMessage()
        _append_message!(input_messages[invariant_index], new_message)
        return
    end
    input_messages[invariant_index] = _init_message(InputType(invariant), new_message)
end

_init_message(::SingleType, first_message::DAGMessage) = first_message
_init_message(::VectorType, first_message::DAGMessage) = DAGMessagesVector(typeof(first_message), [first_message])
_init_message(::VectorType, first_message::DAGMessagesVector{T}) where {T<:DAGMessage} =
    DAGMessagesVector(T, first_message.messages)
_init_message(::MultiType, first_message::T) where {T<:DAGMessage} = MultiTypedDAGMessages(T, DAGMessage[first_message])
_init_message(::MultiType, first_message::DAGMessagesVector{T}) where {T<:DAGMessage} =
    MultiTypedDAGMessages(T, Vector{DAGMessage}(first_message.messages))

_append_message!(current_message::DAGMessagesVector, message::DAGMessage) = push!(current_message.messages, message)
_append_message!(current_message::DAGMessagesVector, message::DAGMessagesVector) =
    append!(current_message.messages, message)
_append_message!(current_message::MultiTypedDAGMessages, message::DAGMessage) =
    push!(all_messages(current_message), message)
_append_message!(current_message::MultiTypedDAGMessages, message::DAGMessagesVector) =
    append!(all_messages(current_message), message)
_append_message!(::DAGMessage, ::NoMessage) = nothing
_append_message!(::DAGMessagesVector, ::NoMessage) = nothing
_append_message!(::MultiTypedDAGMessages, ::NoMessage) = nothing

export DAGMessage

@testitem "Testing making messages" begin
    struct MockInvariant1 <: JuLS.Invariant end
    struct MockInvariant2 <: JuLS.Invariant end
    struct MockInvariant3 <: JuLS.Invariant end
    struct MockInvariant4 <: JuLS.Invariant end

    JuLS.InputType(::MockInvariant1) = JuLS.SingleType()
    JuLS.InputType(::MockInvariant3) = JuLS.MultiType()

    input_messages = Vector{JuLS.DAGMessage}(undef, 4)

    JuLS.make_input_message!(MockInvariant1(), 1, input_messages, JuLS.FloatDelta(10.0))
    JuLS.make_input_message!(MockInvariant2(), 2, input_messages, JuLS.FloatDelta(10.0))
    JuLS.make_input_message!(MockInvariant3(), 3, input_messages, JuLS.FloatDelta(10.0))

    @test input_messages[1] == JuLS.FloatDelta(10.0)
    @test input_messages[2] isa JuLS.DAGMessagesVector
    @test all(input_messages[2] .== JuLS.DAGMessagesVector{JuLS.FloatDelta}([JuLS.FloatDelta(10.0)]))
    @test input_messages[3] isa JuLS.MultiTypedDAGMessages
    @test all(
        input_messages[3].lazy_messages .==
        JuLS.MultiTypedDAGMessages{JuLS.Delta}([JuLS.FloatDelta(10.0)]).lazy_messages,
    )

    @test_throws MethodError JuLS.make_input_message!(MockInvariant1(), 1, input_messages, JuLS.FloatDelta(11.0))
    JuLS.make_input_message!(MockInvariant2(), 2, input_messages, JuLS.FloatDelta(11.0))
    JuLS.make_input_message!(MockInvariant3(), 3, input_messages, JuLS.FloatDelta(11.0))

    @test input_messages[2] isa JuLS.DAGMessagesVector
    @test all(
        input_messages[2] .== JuLS.DAGMessagesVector{JuLS.FloatDelta}([JuLS.FloatDelta(10.0), JuLS.FloatDelta(11.0)]),
    )
    @test input_messages[3] isa JuLS.MultiTypedDAGMessages
    @test all(
        input_messages[3].lazy_messages .==
        JuLS.MultiTypedDAGMessages{JuLS.Delta}([JuLS.FloatDelta(10.0), JuLS.FloatDelta(11.0)]).lazy_messages,
    )

    JuLS.make_input_message!(
        MockInvariant1(),
        4,
        input_messages,
        JuLS.DAGMessagesVector{JuLS.FloatDelta}([JuLS.FloatDelta(10.0)]),
    )

    @test input_messages[4] isa JuLS.DAGMessagesVector
    @test all(input_messages[4] .== JuLS.DAGMessagesVector{JuLS.FloatDelta}([JuLS.FloatDelta(10.0)]))

    JuLS.make_input_message!(
        MockInvariant1(),
        4,
        input_messages,
        JuLS.DAGMessagesVector{JuLS.FloatDelta}([JuLS.FloatDelta(11.0)]),
    )

    @test input_messages[4] isa JuLS.DAGMessagesVector
    @test all(
        input_messages[4] .== JuLS.DAGMessagesVector{JuLS.FloatDelta}([JuLS.FloatDelta(10.0), JuLS.FloatDelta(11.0)]),
    )
end

@testitem "testing abstract typing" begin
    messages = JuLS.DAGMessagesVector(JuLS.FloatDelta)
    @test isa(messages, JuLS.DAGMessages)

    messages = JuLS.MultiTypedDAGMessages()
    @test isa(messages, JuLS.DAGMessages)
end

@testitem "Testing _is_single_type" begin
    @test JuLS._is_single_type(JuLS.DAGMessage[JuLS.FloatDelta(0.0), JuLS.FloatDelta(0.0)])
    @test !JuLS._is_single_type(JuLS.DAGMessage[JuLS.FloatDelta(0.0), JuLS.NoMessage()])
    @test JuLS._is_single_type(JuLS.DAGMessage[])
end

@testitem "testing iszero" begin
    messages = JuLS.DAGMessagesVector(JuLS.FloatDelta)
    @test iszero(messages)

    messages = JuLS.DAGMessagesVector{JuLS.FloatDelta}([JuLS.FloatDelta(0.0), JuLS.FloatDelta(0.0)])
    @test iszero(messages)

    messages = JuLS.DAGMessagesVector{JuLS.FloatDelta}([JuLS.FloatDelta(0.0), JuLS.FloatDelta(1.0)])
    @test !iszero(messages)

    messages = JuLS.DAGMessage[]
    push!(messages, JuLS.FloatDelta(0.0))
    push!(messages, JuLS.ObjectiveDelta(0.0))

    multi_typed_messages = JuLS.MultiTypedDAGMessages(messages)
    @test iszero(multi_typed_messages)

    messages = JuLS.DAGMessage[]
    push!(messages, JuLS.FloatDelta(0.0))
    push!(messages, JuLS.ObjectiveDelta(1.0))

    multi_typed_messages = JuLS.MultiTypedDAGMessages(messages)
    @test !iszero(multi_typed_messages)
end

@testitem "Testing DAGMessagesVector sum" begin
    delta1 = JuLS.FloatDelta(1.0)

    @test sum(JuLS.DAGMessagesVector{JuLS.FloatDelta}(JuLS.DAGMessage[])) == JuLS.FloatDelta(0.0)
    @test sum(JuLS.DAGMessagesVector{JuLS.FloatDelta}([JuLS.FloatDelta(1.0)])) == JuLS.FloatDelta(1.0)
    @test sum(JuLS.DAGMessagesVector{JuLS.FloatDelta}(JuLS.DAGMessage[JuLS.FloatDelta(1.0)])) == JuLS.FloatDelta(1.0)
end