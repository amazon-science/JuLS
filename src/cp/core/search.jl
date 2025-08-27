# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    solve!(run::CPRun, variable_selection::AbstractVariableSelection, value_selection::AbstractValueSelection)

Explores feasible solutions and add them to array `run.solutions`. Returns :Feasible if at least one solution is found, :Infeasible otherwise.  
"""
function solve!(
    run::CPRun,
    variable_selection::AbstractVariableSelection = MinDomainVariableSelection(),
    value_selection::AbstractValueSelection = MaxDomainValueSelection(),
)
    start!(run.time_limit)
    to_call = Stack{Function}()
    # Starting at the root node with an empty stack
    current_status = expand_dfs!(to_call, run, variable_selection, value_selection)

    while !isempty(to_call)
        current_procedure = pop!(to_call)
        current_status::Union{Nothing,Symbol} = current_procedure(run, current_status)
        if current_status == :LimitStop
            break
        end
    end

    if length(run.solutions) > 0
        return :Feasible
    end

    return :Infeasible
end


"""
    expand_dfs!(to_call::Stack{Function}, run::CPRun, variable_selection::AbstractVariableSelection, value_selection::AbstractValueSelection, new_constraints=nothing)

Add procedures to `to_call`, that, called in the stack order (LIFO) with the `run` parameter, will perform a DFS in the graph.
Some procedures will contain a call to `expand_dfs!` itself. Each `expand_dfs!` call is wrapped around a `save_state!` and a `restore_state!` to be
able to backtrack thanks to the trailer.
"""
function expand_dfs!(
    to_call::Stack{Function},
    run::CPRun,
    variable_selection::AbstractVariableSelection,
    value_selection::AbstractValueSelection,
    new_constraints = nothing;
)
    feasible = fix_point!(run, new_constraints)

    if !feasible
        return :Infeasible
    end

    if solutionFound(run)
        return :FoundSolution
    end

    if is_above(run.time_limit)
        return :LimitStop
    end

    x = variable_selection(run)
    v = value_selection(run, x)

    push!(to_call, (run, current_status) -> (restore_state!(run.trailer); :BackTracking))
    push!(
        to_call,
        (run, current_status) -> (remove!(x, v);
        expand_dfs!(to_call, run, variable_selection, value_selection, get_on_domain_change(x))),
    )
    push!(to_call, (run, current_status) -> (save_state!(run.trailer); :SavingState))

    push!(to_call, (run, current_status) -> (restore_state!(run.trailer); :BackTracking))
    push!(
        to_call,
        (run, current_status) -> (assign!(x, v);
        expand_dfs!(to_call, run, variable_selection, value_selection, get_on_domain_change(x))),
    )
    push!(to_call, (run, current_status) -> (save_state!(run.trailer); :SavingState))

    return :Feasible
end



@testitem "expand_dfs!()" begin
    # :Infeasible
    trailer = JuLS.Trailer()
    run = JuLS.CPRun(trailer)

    x = JuLS.IntVariable(2, 2, trailer)
    y = JuLS.IntVariable(3, 3, trailer)
    JuLS.add_variable!(run, x)
    JuLS.add_variable!(run, y)
    JuLS.add_constraint!(run, JuLS.Equal(x, y, trailer))

    to_call = JuLS.Stack{Function}()
    @test JuLS.expand_dfs!(
        to_call,
        run,
        JuLS.MinDomainVariableSelection(),
        JuLS.MaxDomainValueSelection(),
        run.constraints,
    ) == :Infeasible
    @test isempty(to_call)

    # :Feasible
    trailer = JuLS.Trailer()
    run = JuLS.CPRun(trailer)

    x = JuLS.IntVariable(2, 2, trailer)
    y = JuLS.IntVariable(2, 2, trailer)
    JuLS.add_variable!(run, x)
    JuLS.add_variable!(run, y)
    JuLS.add_constraint!(run, JuLS.Equal(x, y, trailer))

    to_call = JuLS.Stack{Function}()
    @test JuLS.expand_dfs!(to_call, run, JuLS.MinDomainVariableSelection(), JuLS.MaxDomainValueSelection()) ==
          :FoundSolution
    @test isempty(to_call)


    ### Checking stack ###
    trailer = JuLS.Trailer()
    run = JuLS.CPRun(trailer)

    x = JuLS.IntVariable(1, 2, 3, trailer)
    y = JuLS.IntVariable(2, 2, 3, trailer)
    JuLS.add_variable!(run, x)
    JuLS.add_variable!(run, y)
    JuLS.add_constraint!(run, JuLS.Equal(x, y, trailer))

    to_call = JuLS.Stack{Function}()
    @test JuLS.expand_dfs!(to_call, run, JuLS.MinDomainVariableSelection(), JuLS.MaxDomainValueSelection()) == :Feasible
    @test length(to_call) == 6

    @test pop!(to_call)(run, :dummySymbol) == :SavingState
    @test length(run.trailer.prior) == 1 # save_state!()

    @test pop!(to_call)(run, :dummySymbol) == :FoundSolution
    @test length(run.solutions) == 1 # Found a solution

    @test pop!(to_call)(run, :dummySymbol) == :BackTracking
    @test length(run.trailer.prior) == 0 # restore_state!()

    @test pop!(to_call)(run, :dummySymbol) == :SavingState
    @test length(run.trailer.prior) == 1 # save_state!()

    @test pop!(to_call)(run, :dummySymbol) == :FoundSolution
    @test length(run.solutions) == 2 # Found another solution

    @test pop!(to_call)(run, :dummySymbol) == :BackTracking
    @test length(run.trailer.prior) == 0 # restore_state!()
end


@testitem "solve!()" begin
    ### Checking status ###

    # :Infeasible
    trailer = JuLS.Trailer()
    run = JuLS.CPRun(trailer)

    x = JuLS.IntVariable(1, 2, 2, trailer)
    y = JuLS.IntVariable(2, 3, 3, trailer)
    JuLS.add_variable!(run, x)
    JuLS.add_variable!(run, y)
    JuLS.add_constraint!(run, JuLS.Equal(x, y, trailer))

    @test JuLS.solve!(run) == :Infeasible

    # :Feasible
    trailer = JuLS.Trailer()
    run = JuLS.CPRun(trailer)

    x = JuLS.IntVariable(1, 2, 2, trailer)
    y = JuLS.IntVariable(2, 2, 2, trailer)
    JuLS.add_variable!(run, x)
    JuLS.add_variable!(run, y)
    JuLS.add_constraint!(run, JuLS.Equal(x, y, trailer))

    @test JuLS.solve!(run) == :Feasible
    @test length(run.solutions) == 1


    ### Checking more complex solutions ###
    trailer = JuLS.Trailer()
    run = JuLS.CPRun(trailer)

    x = JuLS.IntVariable(1, 2, 3, trailer)
    y = JuLS.IntVariable(2, 2, 3, trailer)
    JuLS.add_variable!(run, x)
    JuLS.add_variable!(run, y)
    JuLS.add_constraint!(run, JuLS.Equal(x, y, trailer))

    @test JuLS.solve!(run) == :Feasible
    @test length(run.solutions) == 2
    @test run.solutions[1] == [3, 3]
    @test run.solutions[2] == [2, 2]

end