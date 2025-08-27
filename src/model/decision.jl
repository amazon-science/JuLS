# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    DecisionValue

Abstract type representing a value that can be assigned to a decision variable in an optimization problem.
This serves as the base type for specific value types like binary or integer decisions.
"""
abstract type DecisionValue end

"""
    IntDecisionValue <: DecisionValue

Represents an integer decision value.

# Fields
- `value::Int`: The integer value of the decision
"""
struct IntDecisionValue <: DecisionValue
    value::Int
end
DecisionValue(value::Int) = IntDecisionValue(value)
Base.zero(::Type{IntDecisionValue}) = IntDecisionValue(0)

"""
    BinaryDecisionValue <: DecisionValue

Represents a binary (Boolean) decision value.

# Fields
- `value::Bool`: The boolean value of the decision
"""
struct BinaryDecisionValue <: DecisionValue
    value::Bool
end
DecisionValue(value::Bool) = BinaryDecisionValue(value)
Base.zero(::Type{BinaryDecisionValue}) = BinaryDecisionValue(false)

"""
    DecisionVariable{T<:DecisionValue}

Represents a decision variable in an optimization problem.

# Fields
- `index::Int`: Unique identifier for the variable
- `domain::Vector{T}`: Vector of possible values the variable can take
- `current_value::T`: Current assigned value of the variable

# Type Parameters
- `T`: Type of DecisionValue this variable can hold

# Constructor
    DecisionVariable(index::Int, domain::Vector{T}, current_value::T) where {T<:DecisionValue}

# Errors
Throws an assertion error if current_value is not in the domain
"""
mutable struct DecisionVariable{T<:DecisionValue}
    index::Int
    domain::Vector{T}
    current_value::T

    function DecisionVariable(index::Int, domain::Vector{T}, current_value::T) where {T<:DecisionValue}
        @assert current_value in domain "You cannot instantiate a DecisionVariable with a value not contained in its domain"
        return new{T}(index, domain, current_value)
    end
end

"""
    DecisionVariable(index::Int, current_value::DecisionValue)

Creates a DecisionVariable with a single-value domain.
"""
DecisionVariable(index::Int, current_value::DecisionValue) = DecisionVariable(index, [current_value], current_value)

"""
    DecisionVariable(index::Int, bool::Bool)

Creates a binary DecisionVariable with a domain of [0,1] and initial value at bool.
"""
DecisionVariable(index::Int, bool::Bool) =
    DecisionVariable(index, [BinaryDecisionValue(0), BinaryDecisionValue(1)], BinaryDecisionValue(bool))

"""
    DecisionVariablesArray <: MoveEvaluatorInput

Array structure containing multiple decision variables to be used as an input of a move evaluator (ex: DAG)

# Fields
- `variables::Array{DecisionVariable}`: Array of decision variables
"""
struct DecisionVariablesArray <: MoveEvaluatorInput
    variables::Array{DecisionVariable}
end

"""
    impacted_variables(a::DecisionVariablesArray)

Returns the array of variables contained in the DecisionVariablesArray.
"""
impacted_variables(a::DecisionVariablesArray) = a.variables