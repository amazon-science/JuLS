# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    (::SimpleInitialization)(e::KnapsackExperiment)

Simple initialization strategy for Knapsack Problem that sets all items as unselected.
"""
(::SimpleInitialization)(e::KnapsackExperiment) = fill(false, e.n_items)

"""
    (::GreedyInitialization)(e::KnapsackExperiment)

Greedy initialization strategy for Knapsack Problem based on value-to-weight ratios.

# Algorithm
1. Calculate value-to-weight ratio for each item
2. Sort items by ratio in descending order
3. Select items in order until capacity is reached
"""
function (::GreedyInitialization)(e::KnapsackExperiment)
    item_ratios = [e.values[i] / e.weights[i] for i = 1:e.n_items]
    sorted_indexes = sortperm(item_ratios, rev = true)
    solution = fill(false, e.n_items)
    current_weight = 0
    for i = 1:e.n_items
        item_index = sorted_indexes[i]
        current_weight += e.weights[item_index]
        if current_weight > e.capacity
            break
        end
        solution[item_index] = true
    end
    return solution
end

@testitem "(::GreedyInitialization)(::KnapsackExperiment)" begin
    e = JuLS.KnapsackExperiment(JuLS.PROJECT_ROOT * "/data/knapsack/ks_4_0")
    greedy = JuLS.GreedyInitialization()
    @test greedy(e) == [true, true, false, false]
end