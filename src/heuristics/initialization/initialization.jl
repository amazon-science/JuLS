# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    SimpleInitialization <: InitializationHeuristic

A basic initialization strategy that typically assigns default or random values to variables.
Must be implemented as (::SimpleInitialization)(e::YourExperiment) and return a vector of values indexed by decision variables.
"""
struct SimpleInitialization <: InitializationHeuristic end

"""
    GreedyInitialization <: InitializationHeuristic

An initialization strategy that uses a greedy approach to assign initial values.
Must be implemented as (::GreedyInitialization)(e::YourExperiment) and return a vector of values indexed by decision variables.
"""
struct GreedyInitialization <: InitializationHeuristic end