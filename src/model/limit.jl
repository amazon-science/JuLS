# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

abstract type Limit end

struct IterationLimit <: Limit
    n_iterations::Int
end

mutable struct TimeLimit <: Limit
    start_time::Float64
    limit::Float64
end
TimeLimit() = TimeLimit(0, typemax(Float64))
TimeLimit(limit::Number) = TimeLimit(0, limit)

init!(time_limit::TimeLimit, limit::Number) = time_limit.limit = limit
start!(time_limit::TimeLimit) = time_limit.start_time = time()
is_above(time_limit::TimeLimit) = time() - time_limit.start_time > time_limit.limit


@testitem "TimeLimit" begin
    time_limit = JuLS.TimeLimit()
    JuLS.init!(time_limit, 0.1)
    JuLS.start!(time_limit)
    @test !JuLS.is_above(time_limit)
    sleep(0.1)
    @test JuLS.is_above(time_limit)
end

