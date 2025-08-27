# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    abstract type CPConverter end

Abstract type for DAG elements to Constraint Programming (CP) format. For example converting DateTime to integer. 
Defines conversion strategy for various elements (variables, values, sets, invariants).
A default converter ClassicCPConverter is provided for problems with only binary and integer variables. 
"""
abstract type CPConverter end

struct ClassicCPConverter <: CPConverter end

(::CPConverter)(value::Any) = value

### DECISION VALUE 
(converter::CPConverter)(decision_value::BinaryDecisionValue) = decision_value
(converter::CPConverter)(decision_value::IntDecisionValue) = decision_value
(converter::CPConverter)(decision_value::T) where {T<:DecisionValue} = IntDecisionValue(converter(decision_value.value))

### DECISION VARIABLE
(converter::CPConverter)(decision_variable::DecisionVariable{IntDecisionValue}, trailer::Trailer) =
    IntVariable(decision_variable.index, [v.value for v in decision_variable.domain], trailer)
(converter::CPConverter)(decision_variable::DecisionVariable{BinaryDecisionValue}, trailer::Trailer) =
    BoolVariable(decision_variable.index, trailer)

### ABSTRACTSET
(converter::CPConverter)(interval::Interval) =
    Interval{Int}(converter(interval.inf, ceil), converter(interval.sup, floor))
(converter::CPConverter)(singleton::Singleton) = Singleton{Int}(converter(singleton.value))
(converter::CPConverter)(ds::DoubleSet) = DoubleSet{Int}(converter(ds.first_set), converter(ds.second_set))

### INVARIANT
(::CPConverter)(invariant::Invariant) = invariant
(converter::CPConverter)(invariant::ElementInvariant) =
    ElementInvariant{IntDecisionValue}(invariant.output_variable_index, converter.(invariant.elements))
(converter::CPConverter)(invariant::IsDifferentInvariant) =
    IsDifferentInvariant{IntDecisionValue}(converter(invariant.value))
(converter::CPConverter)(invariant::AmongInvariant) = AmongInvariant(converter(invariant.set))
(converter::CPConverter)(invariant::CompositeInvariant) =
    CompositeInvariant(converter.(invariant.invariants), invariant.names)


