# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    abstract type CPMessage <: DAGMessage

Abstract type DAG message used to build a Constraint Programming model according to the DAG structure.
These messages can carry a CPVariable (the invariant output variable) and/or a CPonstraint (inherent to the invariant constraint)
"""
abstract type CPMessage <: DAGMessage end

cp_variable(::DAGMessage) = nothing
cp_constraint(::DAGMessage) = nothing

"""
    struct CPConstraintMessage <: CPMessage

Message type containing a single CP constraint. 
"""
struct CPConstraintMessage <: CPMessage
    constraint::CPConstraint
end
cp_constraint(message::CPConstraintMessage) = message.constraint

"""
    struct CPVariableMessage <: CPMessage

Message type containing a single CP variable. Used for decision variables or variable view (where no CPConstraint is needed)
"""
struct CPVariableMessage <: CPMessage
    variable::CPVariable
end
cp_variable(message::CPVariableMessage) = message.variable

"""
    struct IntermediateCPVariableMessage <: CPMessage

Message type containing a single CP variable and a CP constraint. 
Used for intermediate variables (invariant output variable), these variables are defined by an inherent constraint. 
"""
struct IntermediateCPVariableMessage <: CPMessage
    variable::CPVariable
    inner_constraint::CPConstraint
end
cp_variable(message::IntermediateCPVariableMessage) = message.variable
cp_constraint(message::IntermediateCPVariableMessage) = message.inner_constraint

