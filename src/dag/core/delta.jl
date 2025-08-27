# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    ScalarDelta <: Delta
    ScalarFullMessage <: FullMessage

Abstract types for scalar-valued deltas and full messages in DAG evaluation.
"""
abstract type ScalarDelta <: Delta end
abstract type ScalarFullMessage <: FullMessage end

output_string(::DAGMessage) = nothing
output_string(m::ScalarFullMessage) = string(m.value)

"""
    FloatDelta <: ScalarDelta
    FloatFullMessage <: ScalarFullMessage

Concrete types for floating-point values in delta updates and full messages.

# Fields
- `value::Float64`: The numerical value
"""
struct FloatDelta <: ScalarDelta
    value::Float64
end
struct FloatFullMessage <: ScalarFullMessage
    value::Float64
end

# This is going to be useful for broadcasting single elements.
Base.length(::DAGMessage) = 1
Base.iterate(δ::DAGMessage) = (δ, nothing)
Base.iterate(::DAGMessage, ::Nothing) = nothing

Base.zero(::DAGMessage) = nothing
Base.zero(delta::T) where {T<:ScalarDelta} = T(zero(delta.value))
Base.zero(::Type{T}) where {T<:Union{ScalarDelta,ScalarFullMessage}} = T(zero(Float64))

Base.:+(delta1::T, delta2::Union{ScalarDelta,ScalarFullMessage}) where {T<:Union{ScalarDelta,ScalarFullMessage}} =
    T(delta1.value + delta2.value)
Base.:+(δ::T, scalar::Number) where {T<:Union{ScalarDelta,ScalarFullMessage}} = T(δ.value + scalar)
Base.:-(δ::T, scalar::Number) where {T<:Union{ScalarDelta,ScalarFullMessage}} = T(δ.value - scalar)
Base.:-(delta1::T, delta2::Union{ScalarDelta,ScalarFullMessage}) where {T<:Union{ScalarDelta,ScalarFullMessage}} =
    T(delta1.value - delta2.value)
Base.:*(scalar::Number, delta::T) where {T<:Union{ScalarDelta,ScalarFullMessage}} = T(scalar * delta.value)
Base.isless(delta::Union{ScalarDelta,ScalarFullMessage}, scalar::Number) = isless(delta.value, scalar)
Base.isless(scalar::Number, delta::Union{ScalarDelta,ScalarFullMessage}) = delta > scalar
Base.convert(T::Type{<:ScalarDelta}, x::FloatDelta) = T(x.value)
Base.convert(T::Type{<:Union{ScalarDelta,ScalarFullMessage}}, x::Number) = T(x)
Base.convert(T::Type{<:ScalarFullMessage}, x::FloatFullMessage) = T(x.value)

Base.convert(::Type{Float64}, x::DAGMessage) = nothing
Base.convert(::Type{Float64}, x::Vector{<:DAGMessage}) = nothing
Base.convert(::Type{Float64}, x::Union{ScalarDelta,ScalarFullMessage}) = x.value

"""
    shouldearlystop(message::DAGMessage, evaluator::MoveEvaluator)

Determines whether DAG evaluation should terminate early based on message content.

# Returns
- `false` for single generic DAGMessage (by default)
- For vector: `true` if vector contains single message that triggers early stop
- `false` otherwise

# Description
Default behavior is to continue evaluation unless specifically triggered by:
- Constraint violation exceeding threshold
- Explicit early stop message
- Single message in vector that triggers early stop
"""
shouldearlystop(::DAGMessage, ::MoveEvaluator) = false
shouldearlystop(messages::Vector{<:DAGMessage}, dag::MoveEvaluator) =
    length(messages) == 1 && shouldearlystop(messages[1], dag)

"""
    EarlyStopDelta <: Delta

Special delta type indicating evaluation should terminate early.

Used for optimization shortcuts when further evaluation is unnecessary.
"""
struct EarlyStopDelta <: Delta end
shouldearlystop(::EarlyStopDelta, ::MoveEvaluator) = true

"""
    ObjectiveDelta <: ScalarDelta
    ObjectiveFullMessage <: ScalarFullMessage

Types representing objective impact for delta and full evaluation. 
"""
struct ObjectiveDelta <: ScalarDelta
    value::Float64
end
struct ObjectiveFullMessage <: ScalarFullMessage
    value::Float64
end

"""
    ConstraintDelta <: ScalarDelta
    ConstraintFullMessage <: ScalarFullMessage

Types representing constraint violation values.

Used for tracking feasibility and constraint satisfaction.
ConstraintDelta triggers an early stop if its value is greater than `early_stop_threshold(dag)`
"""
struct ConstraintDelta <: ScalarDelta
    value::Float64
end
struct ConstraintFullMessage <: ScalarFullMessage
    value::Float64
end
shouldearlystop(δ::ConstraintDelta, dag::MoveEvaluator) = δ.value > early_stop_threshold(dag)


struct IndexDelta <: Delta
    value::Int
end

"""
    SingleVariableMoveDelta{T<:DecisionValue} <: Delta

Represents a change in a single decision variable.

# Fields
- `index::Int`: Variable index
- `current_value::T`: Current value
- `new_value::T`: Proposed new value

# Description
Used to track individual variable changes within a move,
enabling efficient delta evaluation.
"""
struct SingleVariableMoveDelta{T<:DecisionValue} <: Delta
    index::Int
    current_value::T
    new_value::T
end
SingleVariableMoveDelta(current_value::T, new_value::U) where {T,U} =
    SingleVariableMoveDelta(0, DecisionValue(current_value), DecisionValue(new_value))
SingleVariableMoveDelta(index::Int, current_value::T, new_value::U) where {T,U} =
    SingleVariableMoveDelta(index, DecisionValue(current_value), DecisionValue(new_value))

Base.:+(delta1::SingleVariableMoveDelta, delta2::SingleVariableMoveDelta) = SingleVariableMoveDelta(
    delta1.current_value.value + delta2.current_value.value,
    delta1.new_value.value + delta2.new_value.value,
)
Base.:-(delta1::SingleVariableMoveDelta, delta2::SingleVariableMoveDelta) = SingleVariableMoveDelta(
    delta1.current_value.value - delta2.current_value.value,
    delta1.new_value.value - delta2.new_value.value,
)

"""
    SingleVariableMessage{T<:DecisionValue} <: FullMessage

Represents the value of a single decision variable for full evaluation through the DAG.

# Fields
- `index::Int`: Index of the variable in the decision variable array
- `value::T`: Current value of the variable of type T <: DecisionValue

# Description
 Supports both integer and binary decision values.
"""
struct SingleVariableMessage{T<:DecisionValue} <: FullMessage
    index::Int
    value::T
end
SingleVariableMessage(value::T) where {T} = SingleVariableMessage(0, DecisionValue(value))
SingleVariableMessage(index::Int, value::T) where {T} = SingleVariableMessage(index, DecisionValue(value))
output_string(m::SingleVariableMessage{BinaryDecisionValue}) = string(Float64(m.value.value))

Base.:+(m1::SingleVariableMessage, m2::SingleVariableMessage) = SingleVariableMessage(m1.value.value + m2.value.value)
Base.:-(m1::SingleVariableMessage, m2::SingleVariableMessage) = SingleVariableMessage(m1.value.value - m2.value.value)

"""
    ResultDelta <: Delta
    ResultMessage <: FullMessage

Types representing final evaluation results.

# Fields
ResultDelta:
- `objective_delta::Float64`: Change in objective value
- `isfeasible::Bool`: Feasibility status

ResultMessage:
- `objective::Float64`: Objective value
- `constraint::Float64`: Constraint violation value
- `isfeasible::Bool`: Feasibility status
"""
struct ResultDelta <: Delta
    objective_delta::Float64
    isfeasible::Bool
end
struct ResultMessage <: FullMessage
    objective::Float64
    constraint::Float64
    isfeasible::Bool
end


@testitem "Test + for FloatDelta" begin
    @test JuLS.FloatDelta(1) + JuLS.FloatDelta(4) == JuLS.FloatDelta(5)
end

@testitem "Test + for ObjectiveDelta" begin
    @test JuLS.ObjectiveDelta(1) + JuLS.ObjectiveDelta(4) == JuLS.ObjectiveDelta(5)
    @test JuLS.ObjectiveDelta(1) + JuLS.FloatDelta(4) == JuLS.ObjectiveDelta(5)
end

@testitem "Test convert float delta to objective delta" begin
    delta = JuLS.FloatDelta(10.0)
    @test convert(JuLS.ObjectiveDelta, delta) == JuLS.ObjectiveDelta(10.0)
end

@testitem "Test convert float delta to Float" begin
    delta = JuLS.FloatDelta(10.0)
    @test convert(Float64, delta) == 10.0
    deltas = [JuLS.FloatDelta(3.0), JuLS.FloatDelta(5.0)]
    @test convert(Float64, deltas) === nothing
    deltas = [JuLS.FloatFullMessage(3.0), JuLS.FloatFullMessage(5.0)]
    @test convert(Float64, deltas) === nothing
    deltas = JuLS.FullMessage[JuLS.FloatFullMessage(3.0), JuLS.FloatFullMessage(5.0)]
    @test convert(Float64, deltas) === nothing
end

@testitem "Test + for ConstraintDelta" begin
    @test JuLS.ConstraintDelta(1) + JuLS.ConstraintDelta(4) == JuLS.ConstraintDelta(5)
    @test JuLS.ConstraintDelta(1) + JuLS.FloatDelta(4) == JuLS.ConstraintDelta(5)
end

@testitem "Test * for ConstraintDelta" begin
    @test 2 * JuLS.ConstraintDelta(4) == JuLS.ConstraintDelta(8)
    @test 2.0 * JuLS.ConstraintDelta(4) == JuLS.ConstraintDelta(8)
    @test_throws MethodError JuLS.ConstraintDelta(1) * 2 # no commutativity
end

@testitem "Test - for ConstraintDelta" begin
    @test JuLS.ConstraintDelta(8) - JuLS.ConstraintDelta(2) == JuLS.ConstraintDelta(6)
end

@testitem "Test convert float delta to constraint delta" begin
    delta = JuLS.FloatDelta(10.0)
    @test convert(JuLS.ConstraintDelta, delta) == JuLS.ConstraintDelta(10.0)
end

@testitem "Test zero for non scalar delta" begin
    struct MockDelta <: JuLS.DAGMessage end

    @test !iszero(MockDelta())
end

@testitem "Test zero for scalar delta" begin
    delta1 = JuLS.FloatDelta(10.0)
    delta2 = JuLS.FloatDelta(0.0)

    @test !iszero(delta1)
    @test iszero(delta2)
    @test iszero(zero(JuLS.FloatDelta))
end

@testitem "Test output name" begin
    delta = JuLS.FloatDelta(10.0)
    message = JuLS.FloatFullMessage(0.0)

    @test JuLS.output_string(delta) === nothing
    @test JuLS.output_string(message) == "0.0"
end