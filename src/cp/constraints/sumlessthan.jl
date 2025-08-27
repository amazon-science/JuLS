# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
     struct SumLessThan <: CPConstraint
 
 CPConstraint ∑(x_i ∀ i ∈ |x|) ≤ upper
 
 **Filtering**: 
 The goal is to enforce the constraint:
 ∑(x_i ∀ i ∈ |x|) ≤ upper
 
 We can rewrite as:
 x_i + ∑(x_j ∀ j != i) ≤ upper → x_i ≤ - ∑(x_j ∀ j != i) + upper
 
 Therefore, the tighest bound on x_i (maximum value x_i can take) is: 
 x_i = - ∑(x_j ∀ j != i) + upper
 
 We know that: 
 1) - ∑(x_j ∀ j != i) ≤ - ∑(min(x_j) ∀ j != i)
 2) - ∑(min(x_j) ∀ j != i) = min(x_i) - ∑(min(x_i) ∀ i ∈ |x|)
 
 Rewrite:
 - ∑(x_j ∀ j != i) ≤ min(x_i) - ∑(min(x_i) ∀ i ∈ |x|)
    x_i - upper    ≤ min(x_i) - ∑(min(x_i) ∀ i ∈ |x|)
 
 ⟹ **x_i ≤ min(x_i) - ∑(min(x_i) ∀ i ∈ |x|) + upper**
 This means that we can prune all values greater than - ∑(min(x_j) ∀ j != i) + upper from x_i's domain
 """
struct SumLessThan <: CPConstraint
    x::Vector{CPVariable}
    upper::Int
    active::StateObject{Bool}
    number_of_free_vars::StateObject{Int}
    sum_of_fixed_vars::StateObject{Int}
    free_ids::Vector{Int}

    function SumLessThan(x::Vector{CPVariable}, upper::Int, trailer::Trailer)
        @assert !isempty(x)

        free_ids = zeros(length(x))
        for i = 1:length(x)
            free_ids[i] = i
        end

        constraint = new(
            x,
            upper,
            StateObject{Bool}(true, trailer),
            StateObject{Int}(length(x), trailer),
            StateObject{Int}(0, trailer),
            free_ids,
        )
        for xi in x
            add_on_domain_change!(xi, constraint)
        end
        return constraint
    end
end

function propagate!(constraint::SumLessThan, to_propagate::Set{CPConstraint})
    if !constraint.active.value
        return false
    end

    # Computing min_sum, max_sum and actualising other variables
    new_number_of_free_vars = constraint.number_of_free_vars.value
    sum_of_min = constraint.sum_of_fixed_vars.value
    for i = new_number_of_free_vars:-1:1
        var = constraint.x[constraint.free_ids[i]]
        sum_of_min += minimum(var.domain)

        if isbound(var)
            set_value!(constraint.sum_of_fixed_vars, constraint.sum_of_fixed_vars.value + assigned_value(var))
            constraint.free_ids[i], constraint.free_ids[new_number_of_free_vars] =
                constraint.free_ids[new_number_of_free_vars], constraint.free_ids[i]
            new_number_of_free_vars -= 1
        end
    end
    set_value!(constraint.number_of_free_vars, new_number_of_free_vars)

    # Feasiblilty check
    if sum_of_min > constraint.upper
        return false
    end

    for i = new_number_of_free_vars:-1:1
        var = constraint.x[constraint.free_ids[i]]
        pruned_upper = remove_above!(var.domain, minimum(var.domain) - sum_of_min + constraint.upper)
        if pruned_upper
            if isempty(var.domain)
                return false
            end
            trigger_domain_change!(to_propagate, var)
        end
    end
    if new_number_of_free_vars == 0
        set_value!(constraint.active, false)
    end
    return true
end

@testitem "SumLessThan()" begin
    trailer = JuLS.Trailer()

    x1 = JuLS.IntVariable(2, 6, trailer)
    x2 = JuLS.IntVariable(2, 6, trailer)
    x3 = JuLS.IntVariable(2, 6, trailer)
    x = JuLS.CPVariable[x1, x2, x3]

    constraint = JuLS.SumLessThan(x, 12, trailer)
    @test constraint.x == [x1, x2, x3]
    @test constraint.active.value == true
    @test constraint.number_of_free_vars.value == 3
    @test constraint.sum_of_fixed_vars.value == 0
    @test constraint.free_ids == [1, 2, 3]
    @test JuLS.is_active(constraint)
end

@testitem "propagate!(::SumLessThan) for feasible" begin
    trailer = JuLS.Trailer()

    x1 = JuLS.IntVariable(-3, 3, trailer)
    x2 = JuLS.IntVariable(-3, 3, trailer)
    x3 = JuLS.IntVariable(-3, 3, trailer)
    x = JuLS.CPVariable[x1, x2, x3]

    constraint = JuLS.SumLessThan(x, 6, trailer)
    to_propagate = Set{JuLS.CPConstraint}()

    JuLS.assign!(x1.domain, 3)
    JuLS.assign!(x2.domain, -2)
    JuLS.assign!(x3.domain, -1)

    @test JuLS.propagate!(constraint, to_propagate)
    @test constraint.number_of_free_vars.value == 0
    @test constraint.sum_of_fixed_vars.value == 0
    @test JuLS.is_active(constraint) == false
end

@testitem "propagate!(::SumLessThan) domain pruning" begin
    trailer = JuLS.Trailer()

    x1 = JuLS.IntVariable(1, 5, trailer)
    x2 = JuLS.IntVariable(1, 5, trailer)
    x3 = JuLS.IntVariable(1, 5, trailer)
    x = JuLS.CPVariable[x1, x2, x3]

    constraint = JuLS.SumLessThan(x, 6, trailer)
    to_propagate = Set{JuLS.CPConstraint}()

    JuLS.assign!(x1.domain, 3)
    JuLS.assign!(x2.domain, 2)

    @test JuLS.propagate!(constraint, to_propagate)
    @test constraint.number_of_free_vars.value == 1
    @test constraint.sum_of_fixed_vars.value == 5
    @test 1 in x3.domain
    @test JuLS.assigned_value(x3) == 1
    @test JuLS.is_active(constraint) == true
end

@testitem "propagate!(::SumLessThan) domain pruning 2" begin
    trailer = JuLS.Trailer()

    x1 = JuLS.IntVariable(1, 6, trailer)
    x2 = JuLS.IntVariable(3, 6, trailer)
    x3 = JuLS.IntVariable(3, 5, trailer)
    x = JuLS.CPVariable[x1, x2, x3]

    constraint = JuLS.SumLessThan(x, 10, trailer)
    to_propagate = Set{JuLS.CPConstraint}()

    @test (6 in x1.domain) && (5 in x1.domain)
    @test JuLS.propagate!(constraint, to_propagate)
    @test constraint.number_of_free_vars.value == 3
    @test !(6 in x1.domain) && !(5 in x1.domain)

    @test JuLS.is_active(constraint) == true
end

@testitem "propagate!(::SumLessThan) infeasible" begin
    trailer = JuLS.Trailer()

    x1 = JuLS.IntVariable(1, 5, trailer)
    x2 = JuLS.IntVariable(6, 11, trailer)
    x3 = JuLS.IntVariable(1, 3, trailer)
    x = JuLS.CPVariable[x1, x2, x3]

    constraint = JuLS.SumLessThan(x, 10, trailer)
    to_propagate = Set{JuLS.CPConstraint}()

    JuLS.assign!(x1.domain, 1)
    JuLS.assign!(x2.domain, 7)
    JuLS.assign!(x3.domain, 3)

    @test !JuLS.propagate!(constraint, to_propagate)
end

@testitem "propagate!(::SumLessThan) to_propagate" begin
    trailer = JuLS.Trailer()

    x1 = JuLS.IntVariable(1, 1, 5, trailer)
    x2 = JuLS.IntVariable(2, 1, 5, trailer)
    x3 = JuLS.IntVariable(3, 1, 5, trailer)

    x = JuLS.CPVariable[x1, x2, x3]
    constraint = JuLS.SumLessThan(x, 5, trailer)
    to_propagate = Set{JuLS.CPConstraint}()

    # No pruning test
    @test JuLS.propagate!(constraint, to_propagate)

    @test length(to_propagate) == 1
    @test length(x1.domain) == 3
    @test length(x2.domain) == 3
    @test length(x3.domain) == 3

    # Propagation test
    JuLS.assign!(x1.domain, 1)
    @test JuLS.propagate!(constraint, to_propagate)
    @test length(to_propagate) == 1
    @test length(x2.domain) == 3
    @test length(x3.domain) == 3
    @test 1 in x2.domain && 2 in x2.domain && 3 in x2.domain
    @test 1 in x3.domain && 2 in x3.domain && 3 in x3.domain

    # Pruning test
    JuLS.assign!(x2.domain, 3)
    @test JuLS.propagate!(constraint, to_propagate)
    @test length(x3.domain) == 1
    @test JuLS.assigned_value(x3) == 1

    # Remove value to check for propagation
    JuLS.remove!(x3.domain, 1)
    @test JuLS.propagate!(constraint, to_propagate)
    @test length(x3.domain) == 0
    @test JuLS.is_active(constraint) == true # No solution with the current assignments, therefore the constraint is still active
end