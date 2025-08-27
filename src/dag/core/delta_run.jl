# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    struct DeltaRun <: CommitableRunMode

Running a DeltaRun means running the DAG incrementally. In fact, every invariant only receives information about
what has changed and nothing about parts that stay the same. Every invariant is also expected to return a "delta"
that represents the difference caused by the move.
This mode is "commitable", it means we can `commit!` a solution move so that every invariant can update their instantiate datastructure that represents the current configuration.
"""
struct DeltaRun <: CommitableRunMode
    input::Move
    istouched::BitVector
    input_messages::Vector{DAGMessage}
end
function DeltaRun(input::Move, dag::DAG)
    istouched, messages = _default_initial_values(input, dag)

    return DeltaRun(input, istouched, messages)
end

delta(r::DeltaRun) = output(r)
delta_obj(r::DeltaRun) = delta(r).objective_delta
delta_obj(r::NoMove) = 0
isfeasible(r::NoMove) = true
isfeasible(r::DeltaRun) = delta(r).isfeasible
move(r::DeltaRun) = r.input
earlystopresult(::DeltaRun) = ResultDelta(typemax(Float64), false)

MoveEvaluatorOutput(run_mode::DeltaRun) = EvaluatedMove(move(run_mode), delta(run_mode))