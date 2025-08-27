# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    MinDistanceInvariant{T, U}

This invariant takes a sequence of values of type T and makes sure that their distance is more than min_distance of type U.
y = min(abs(x-x') for x,x' ∈ X)
"""
mutable struct MinDistanceInvariant{T,U} <: Invariant
    values::Vector{T}
    min_distance::U
    is_currently_broken::Bool
end

MinDistanceInvariant{T,U}(min_distance::U) where {T,U} = MinDistanceInvariant(T[], min_distance, false)

function eval(
    invariant::MinDistanceInvariant{T,U},
    deltas::DAGMessagesVector{SingleVariableMoveDelta{V}},
) where {T,U,V<:DecisionValue}
    new_sorted_values = deepcopy(invariant.values)

    _apply_deltas!(new_sorted_values, deltas)

    return ConstraintDelta(
        1000 * (_is_broken(invariant.min_distance, new_sorted_values) - invariant.is_currently_broken),
    )
end

function commit!(
    invariant::MinDistanceInvariant{T,U},
    deltas::DAGMessagesVector{SingleVariableMoveDelta{V}},
) where {T,U,V<:DecisionValue}
    _apply_deltas!(invariant.values, deltas)

    invariant.is_currently_broken = _is_broken(invariant.min_distance, invariant.values)
end

function eval(
    invariant::MinDistanceInvariant{T,U},
    messages::DAGMessagesVector{SingleVariableMessage{V}},
) where {T,U,V<:DecisionValue}
    values = sort([message.value.value for message in messages if !isnothing(message.value.value)])

    return ConstraintFullMessage(1000.0 * _is_broken(invariant.min_distance, values))
end

function init!(
    invariant::MinDistanceInvariant{T,U},
    messages::DAGMessagesVector{SingleVariableMessage{V}},
) where {T,U,V<:DecisionValue}
    invariant.values = sort([message.value.value for message in messages if !isnothing(message.value.value)])

    if _is_broken(invariant.min_distance, invariant.values)
        invariant.min_distance = _min_distance(invariant.values)
    end

    invariant.is_currently_broken = false

    return eval(invariant, messages)
end

function _apply_deltas!(
    sorted_sequence::Vector{T},
    deltas::DAGMessagesVector{SingleVariableMoveDelta{V}},
) where {T,V<:DecisionValue}
    for delta in deltas
        _apply_delta!(sorted_sequence, delta.current_value.value, delta.new_value.value)
    end
end
function _apply_delta!(
    sorted_sequence::Vector{T},
    current_value::Union{T,Nothing},
    new_value::Union{T,Nothing},
) where {T}
    _delete_value!(sorted_sequence, current_value)
    _insert_value!(sorted_sequence, new_value)
end

_delete_value!(::Vector{T}, ::Nothing) where {T} = nothing
_delete_value!(sorted_sequence::Vector{T}, current_value::T) where {T} =
    deleteat!(sorted_sequence, findfirst(x -> x == current_value, sorted_sequence))

_insert_value!(::Vector{T}, ::Nothing) where {T} = nothing
_insert_value!(sorted_sequence::Vector{T}, new_value::T) where {T} =
    insert!(sorted_sequence, searchsortedfirst(sorted_sequence, new_value), new_value)

_is_broken(min_distance::U, sorted_values::Vector{T}) where {T,U} =
    length(sorted_values) >= 2 && minimum(diff(sorted_values)) < min_distance
_min_distance(sorted_values::Vector{T}) where {T} = minimum(diff(sorted_values))

@testitem "eval min distance invariant delta with ints" begin
    invariant = JuLS.MinDistanceInvariant{Int,Int}(10)

    base_int = 0

    message1 = JuLS.SingleVariableMessage{JuLS.IntDecisionValue}(1, JuLS.IntDecisionValue(base_int))
    message2 = JuLS.SingleVariableMessage{JuLS.IntDecisionValue}(2, JuLS.IntDecisionValue(base_int + 10))
    message3 = JuLS.SingleVariableMessage{JuLS.IntDecisionValue}(3, JuLS.IntDecisionValue(base_int + 30))

    JuLS.init!(invariant, JuLS.DAGMessagesVector([message2, message1, message3]))

    delta1 = JuLS.SingleVariableMoveDelta{JuLS.IntDecisionValue}(
        1,
        JuLS.IntDecisionValue(base_int),
        JuLS.IntDecisionValue(base_int + 40),
    )
    delta2 = JuLS.SingleVariableMoveDelta{JuLS.IntDecisionValue}(
        1,
        JuLS.IntDecisionValue(base_int),
        JuLS.IntDecisionValue(base_int + 25),
    )
    delta3 = JuLS.SingleVariableMoveDelta{JuLS.IntDecisionValue}(
        2,
        JuLS.IntDecisionValue(base_int + 10),
        JuLS.IntDecisionValue(base_int + 45),
    )

    @test JuLS.eval(invariant, JuLS.DAGMessagesVector([delta1])) == JuLS.ConstraintDelta(0.0)
    @test JuLS.eval(invariant, JuLS.DAGMessagesVector([delta2])) == JuLS.ConstraintDelta(1000.0)
    @test JuLS.eval(invariant, JuLS.DAGMessagesVector([delta3])) == JuLS.ConstraintDelta(0.0)

    @test JuLS.eval(invariant, JuLS.DAGMessagesVector([delta1, delta3])) == JuLS.ConstraintDelta(1000.0)

    @test JuLS.eval(
        invariant,
        JuLS.DAGMessagesVector{JuLS.SingleVariableMoveDelta{JuLS.IntDecisionValue}}(
            JuLS.SingleVariableMoveDelta{JuLS.IntDecisionValue}[],
        ),
    ) == JuLS.ConstraintDelta(0.0)
end

@testitem "eval min distance invariant delta repairing constraint" begin
    invariant = JuLS.MinDistanceInvariant{Int,Int}(10)

    base_int = 0

    message1 = JuLS.SingleVariableMessage{JuLS.IntDecisionValue}(1, JuLS.IntDecisionValue(base_int))
    message2 = JuLS.SingleVariableMessage{JuLS.IntDecisionValue}(2, JuLS.IntDecisionValue(base_int + 10))
    message3 = JuLS.SingleVariableMessage{JuLS.IntDecisionValue}(3, JuLS.IntDecisionValue(base_int + 30))

    JuLS.init!(
        invariant,
        JuLS.DAGMessagesVector{JuLS.SingleVariableMessage{JuLS.IntDecisionValue}}([message2, message1, message3]),
    )

    delta1 = JuLS.SingleVariableMoveDelta{JuLS.IntDecisionValue}(
        1,
        JuLS.IntDecisionValue(base_int),
        JuLS.IntDecisionValue(base_int + 25),
    )
    delta2 = JuLS.SingleVariableMoveDelta{JuLS.IntDecisionValue}(
        3,
        JuLS.IntDecisionValue(base_int + 30),
        JuLS.IntDecisionValue(base_int),
    )

    JuLS.commit!(invariant, JuLS.DAGMessagesVector([delta1]))

    @test JuLS.eval(invariant, JuLS.DAGMessagesVector([delta2])) == JuLS.ConstraintDelta(-1000.0)
end

@testitem "commit! min distance invariant delta with ints" begin
    invariant1 = JuLS.MinDistanceInvariant{Int,Int}(10)
    invariant2 = JuLS.MinDistanceInvariant{Int,Int}(10)
    invariant3 = JuLS.MinDistanceInvariant{Int,Int}(10)
    invariant4 = JuLS.MinDistanceInvariant{Int,Int}(10)
    invariant5 = JuLS.MinDistanceInvariant{Int,Int}(10)

    base_int = 0

    message1 = JuLS.SingleVariableMessage{JuLS.IntDecisionValue}(1, JuLS.IntDecisionValue(base_int))
    message2 = JuLS.SingleVariableMessage{JuLS.IntDecisionValue}(2, JuLS.IntDecisionValue(base_int + 10))
    message3 = JuLS.SingleVariableMessage{JuLS.IntDecisionValue}(3, JuLS.IntDecisionValue(base_int + 30))

    JuLS.init!(invariant1, JuLS.DAGMessagesVector([message2, message1, message3]))
    JuLS.init!(invariant2, JuLS.DAGMessagesVector([message2, message1, message3]))
    JuLS.init!(invariant3, JuLS.DAGMessagesVector([message2, message1, message3]))
    JuLS.init!(invariant4, JuLS.DAGMessagesVector([message2, message1, message3]))
    JuLS.init!(invariant5, JuLS.DAGMessagesVector([message2, message1, message3]))

    delta1 = JuLS.SingleVariableMoveDelta{JuLS.IntDecisionValue}(
        1,
        JuLS.IntDecisionValue(base_int),
        JuLS.IntDecisionValue(base_int + 40),
    )
    delta2 = JuLS.SingleVariableMoveDelta{JuLS.IntDecisionValue}(
        1,
        JuLS.IntDecisionValue(base_int),
        JuLS.IntDecisionValue(base_int + 25),
    )
    delta3 = JuLS.SingleVariableMoveDelta{JuLS.IntDecisionValue}(
        2,
        JuLS.IntDecisionValue(base_int + 10),
        JuLS.IntDecisionValue(base_int + 45),
    )

    JuLS.commit!(invariant1, JuLS.DAGMessagesVector([delta1]))

    @test !invariant1.is_currently_broken
    @test invariant1.values == [(base_int + 10), (base_int + 30), (base_int + 40)]
    @test invariant1.min_distance == 10

    JuLS.commit!(invariant2, JuLS.DAGMessagesVector([delta2]))

    @test invariant2.is_currently_broken
    @test invariant2.values == [(base_int + 10), (base_int + 25), (base_int + 30)]
    @test invariant2.min_distance == 10

    JuLS.commit!(invariant3, JuLS.DAGMessagesVector([delta3]))

    @test !invariant3.is_currently_broken
    @test invariant3.values == [(base_int), (base_int + 30), (base_int + 45)]
    @test invariant3.min_distance == 10

    JuLS.commit!(invariant4, JuLS.DAGMessagesVector([delta1, delta3]))

    @test invariant4.is_currently_broken
    @test invariant4.values == [(base_int + 30), (base_int + 40), (base_int + 45)]
    @test invariant4.min_distance == 10

    JuLS.commit!(
        invariant5,
        JuLS.DAGMessagesVector{JuLS.SingleVariableMoveDelta{JuLS.IntDecisionValue}}(
            JuLS.SingleVariableMoveDelta{JuLS.IntDecisionValue}[],
        ),
    )

    @test !invariant5.is_currently_broken
    @test invariant5.values == [(base_int), (base_int + 10), (base_int + 30)]
    @test invariant5.min_distance == 10
end

@testitem "eval min distance invariant full message with ints" begin
    invariant = JuLS.MinDistanceInvariant{Int,Int}(10)

    base_int = 0

    message1 = JuLS.SingleVariableMessage{JuLS.IntDecisionValue}(1, JuLS.IntDecisionValue(base_int))
    message2 = JuLS.SingleVariableMessage{JuLS.IntDecisionValue}(2, JuLS.IntDecisionValue(base_int + 10))
    message3 = JuLS.SingleVariableMessage{JuLS.IntDecisionValue}(3, JuLS.IntDecisionValue(base_int + 15))

    @test JuLS.eval(invariant, JuLS.DAGMessagesVector([message2, message1])) == JuLS.ConstraintFullMessage(0.0)
    @test JuLS.eval(invariant, JuLS.DAGMessagesVector([message2, message1, message3])) ==
          JuLS.ConstraintFullMessage(1000.0)
    @test JuLS.eval(
        invariant,
        JuLS.DAGMessagesVector{JuLS.SingleVariableMessage{JuLS.IntDecisionValue}}(
            JuLS.SingleVariableMessage{JuLS.IntDecisionValue}[],
        ),
    ) == JuLS.ConstraintFullMessage(0.0)
end

@testitem "init! min distance invariant with ints" begin
    invariant1 = JuLS.MinDistanceInvariant{Int,Int}(10)
    invariant2 = JuLS.MinDistanceInvariant{Int,Int}(10)
    invariant3 = JuLS.MinDistanceInvariant{Int,Int}(10)
    invariant4 = JuLS.MinDistanceInvariant{Int,Int}(10)

    base_int = 0

    message1 = JuLS.SingleVariableMessage{JuLS.IntDecisionValue}(1, JuLS.IntDecisionValue(base_int))
    message2 = JuLS.SingleVariableMessage{JuLS.IntDecisionValue}(2, JuLS.IntDecisionValue(base_int + 10))
    message3 = JuLS.SingleVariableMessage{JuLS.IntDecisionValue}(3, JuLS.IntDecisionValue(base_int + 15))

    JuLS.init!(invariant1, JuLS.DAGMessagesVector([message2, message1]))

    @test invariant1.values == [(base_int), (base_int + 10)]
    @test invariant1.min_distance == 10
    @test !invariant1.is_currently_broken

    JuLS.init!(invariant2, JuLS.DAGMessagesVector([message2, message1, message3]))

    @test invariant2.values == [(base_int), (base_int + 10), (base_int + 15)]
    @test invariant2.min_distance == 5
    @test !invariant2.is_currently_broken

    JuLS.init!(
        invariant3,
        JuLS.DAGMessagesVector{JuLS.SingleVariableMessage{JuLS.IntDecisionValue}}(
            JuLS.SingleVariableMessage{JuLS.IntDecisionValue}[],
        ),
    )

    @test invariant3.values == []
    @test invariant3.min_distance == 10
    @test !invariant3.is_currently_broken

    JuLS.init!(invariant4, JuLS.DAGMessagesVector([message1]))

    @test invariant4.values == [0]
    @test invariant4.min_distance == 10
    @test !invariant4.is_currently_broken
end