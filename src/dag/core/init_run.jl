# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct InitRun <: RunMode

Running a InitRun means running every initialisation function of every invariant, starting with the start node, with all the variables information.
That allows the invariants to initialise using the initial configuration. For example, inbound curves that are broken in the initial configuration should be considered as feasible. Hence, the comparator invariant that usually makes sure the backlog is equal to zero is updated so its capacity is equal to the initial backlog.
"""
struct InitRun <: RunMode
    input::DecisionVariablesArray
    istouched::BitVector
    input_messages::Vector{DAGMessage}
end
function InitRun(input::DecisionVariablesArray, dag::DAG)
    istouched, messages = _default_initial_values(input, dag)

    return InitRun(input, istouched, messages)
end

eval(r::InitRun, dag::DAG, index::Int) = init!(invariant(dag, index), input_messages(r, index))
init!(invariant::Invariant, m::DAGMessage) = eval(invariant, m)

