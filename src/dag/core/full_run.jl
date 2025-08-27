# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct FullRun <: RunMode

Running a FullRun means running every invariant of the DAG with the information coming from all variables. 
In fact, all the invariants gets executed with every information from the configuration. The invariants are not
expected to rely On or store anything related to the current solution.
"""
struct FullRun <: RunMode
    input::DecisionVariablesArray
    istouched::BitVector
    input_messages::Vector{DAGMessage}
end
function FullRun(input::DecisionVariablesArray, dag::DAG)
    istouched, messages = _default_initial_values(input, dag)

    return FullRun(input, istouched, messages)
end

Solution(r::FullRun) = Solution([x.current_value for x in r.input.variables], output(r).objective, output(r).isfeasible)