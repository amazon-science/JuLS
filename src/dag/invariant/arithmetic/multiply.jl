# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    MultiplyInvariant <: Invariant

Represents an invariant for multipication. (x_1 * x_2 * ... * x_n)
It maintains the product for the non zero values and the number of zero values separately.

# Fields
- `non_null_product::Float64`: The product of all non-zero values.
- `nb_zeros::Int`: The number of zero values in the set.
"""
mutable struct MultiplyInvariant <: Invariant
    non_null_product::Float64
    nb_zeros::Int
end
MultiplyInvariant() = MultiplyInvariant(1, 0)

InputType(::MultiplyInvariant) = MultiType()

eval(::MultiplyInvariant, messages::MultiTypedDAGMessages{<:FullMessage}) =
    FloatFullMessage(prod([Float64(m.value.value) for m in all_messages(messages)]; init = 1.0))

function eval(invariant::MultiplyInvariant, deltas::MultiTypedDAGMessages{<:Delta})
    deltas = all_messages(deltas)
    current_value = invariant.nb_zeros > 0 ? 0 : invariant.non_null_product

    if invariant.nb_zeros + get_nb_zeros(deltas) != 0
        return FloatDelta(-current_value)
    end

    new_value =
        invariant.non_null_product * prod([Float64(δ.new_value.value) for δ in deltas]; init = 1.0) /
        prod([Float64(δ.current_value.value) for δ in deltas if !iszero(δ.current_value.value)]; init = 1.0)

    return FloatDelta(new_value - current_value)
end

function commit!(invariant::MultiplyInvariant, deltas::MultiTypedDAGMessages{<:Delta})
    deltas = all_messages(deltas)
    invariant.nb_zeros += get_nb_zeros(deltas)

    invariant.non_null_product *=
        prod([Float64(δ.new_value.value) for δ in deltas if !iszero(δ.new_value.value)]; init = 1.0) /
        prod([Float64(δ.current_value.value) for δ in deltas if !iszero(δ.current_value.value)]; init = 1.0)
end

function init!(invariant::MultiplyInvariant, messages::MultiTypedDAGMessages)
    messages = all_messages(messages)
    @assert all(m -> isa(m, SingleVariableMessage), messages) "All input variables for MultiplyInvariant must be SingleVariableMessage"
    invariant.nb_zeros = sum(iszero(m.value.value) for m in messages)
    invariant.non_null_product = prod([Float64(m.value.value) for m in messages if !iszero(m.value.value)]; init = 1.0)
    return FloatFullMessage(invariant.nb_zeros > 0 ? 0 : invariant.non_null_product)
end

get_nb_zeros(deltas::Vector{SingleVariableMoveDelta}) =
    sum(iszero(δ.new_value.value) - iszero(δ.current_value.value) for δ in deltas)

@testitem "init!(::MultiplyInvariant)" begin
    invariant = JuLS.MultiplyInvariant()

    m1 = JuLS.SingleVariableMessage(false)
    m2 = JuLS.SingleVariableMessage(4)
    m3 = JuLS.SingleVariableMessage(0)
    m4 = JuLS.SingleVariableMessage(5)

    messages = JuLS.MultiTypedDAGMessages([m1, m2, m3, m4])

    @test JuLS.init!(invariant, messages) == JuLS.FloatFullMessage(0)
    @test invariant.non_null_product == 20
    @test invariant.nb_zeros == 2
end

@testitem "eval(::MultiplyInvariant, :FullMessage)" begin
    invariant = JuLS.MultiplyInvariant()

    m1 = JuLS.SingleVariableMessage(false)
    m2 = JuLS.SingleVariableMessage(4)
    m3 = JuLS.SingleVariableMessage(0)
    m4 = JuLS.SingleVariableMessage(5)

    messages = JuLS.MultiTypedDAGMessages([m1, m2, m3, m4])
    @test JuLS.eval(invariant, messages) == JuLS.FloatFullMessage(0)

    messages = JuLS.MultiTypedDAGMessages([m2, m4])
    @test JuLS.eval(invariant, messages) == JuLS.FloatFullMessage(20)

    messages = JuLS.MultiTypedDAGMessages([m1, m2, m4])
    @test JuLS.eval(invariant, messages) == JuLS.FloatFullMessage(0)
end

@testitem "eval(::MultiplyInvariant, :Delta)" begin
    invariant = JuLS.MultiplyInvariant(10, 2)

    δ1 = JuLS.SingleVariableMoveDelta(false, true)
    δ2 = JuLS.SingleVariableMoveDelta(5, 2)
    δ3 = JuLS.SingleVariableMoveDelta(0, 3)
    δ4 = JuLS.SingleVariableMoveDelta(5, 0)

    deltas = JuLS.MultiTypedDAGMessages([δ1, δ2, δ3, δ4])
    @test JuLS.eval(invariant, deltas) == JuLS.FloatDelta(0.0)

    deltas = JuLS.MultiTypedDAGMessages([δ1, δ2, δ3])
    @test JuLS.eval(invariant, deltas) == JuLS.FloatDelta(12)

    deltas = JuLS.MultiTypedDAGMessages([δ1, δ2])
    @test JuLS.eval(invariant, deltas) == JuLS.FloatDelta(0.0)

    deltas = JuLS.MultiTypedDAGMessages([δ1, δ3])
    @test JuLS.eval(invariant, deltas) == JuLS.FloatDelta(30)
end

@testitem "commit!(::MultiplyInvariant, :Delta)" begin
    invariant = JuLS.MultiplyInvariant(10, 2)

    δ1 = JuLS.SingleVariableMoveDelta(false, true)
    δ2 = JuLS.SingleVariableMoveDelta(5, 2)
    δ3 = JuLS.SingleVariableMoveDelta(0, 3)
    δ4 = JuLS.SingleVariableMoveDelta(1, 0)

    deltas = JuLS.MultiTypedDAGMessages([δ1, δ2, δ3, δ4])
    JuLS.commit!(invariant, deltas)
    @test invariant.non_null_product == 12.0
    @test invariant.nb_zeros == 1

    deltas = JuLS.MultiTypedDAGMessages([δ1, δ2])
    JuLS.commit!(invariant, deltas)
    @test isapprox(invariant.non_null_product, 4.8)
    @test invariant.nb_zeros == 0
end

