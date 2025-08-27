# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""
    abstract type RelationalOperator

This type defines relational operators that
represents a comparison between two decision values.
"""
abstract type RelationalOperator end

struct EqOp <: RelationalOperator end
struct NeOp <: RelationalOperator end

apply(::EqOp, x, y) = x == y
apply(::NeOp, x, y) = x != y

"""
    struct RelationalInvariant{T<:DecisionValue,R<:RelationalOperator} <: Invariant

This invariant represents a relational constraint between two decision values x and y 
where `T` is the type of the decision values and `R` is the relational operator. Can be used 
to represent equality (==), inequality, (!=), or comparisons (<, >, <=, >=).
This invariant returns a violation of the constraint, if x R y is false, return 1 otherwise 0
"""
struct RelationalInvariant{T<:DecisionValue,R<:RelationalOperator} <: Invariant
    current_values::PairMapping{T}
    comp::R
end

RelationalInvariant{T,R}() where {T<:DecisionValue,R<:RelationalOperator} =
    RelationalInvariant{T,R}(PairMapping{T}(), R())

function init!(
    invariant::RelationalInvariant{T,R},
    messages::DAGMessagesVector{SingleVariableMessage{T}},
) where {T<:DecisionValue,R<:RelationalOperator}
    indexes = [m.index for m in messages]
    @assert length(messages) == 2 "This invariant must have 2 parents : here $indexes"
    setkeys!(invariant.current_values, indexes...)
    for m in messages
        invariant.current_values[m.index] = m.value
    end
    return FloatFullMessage(
        !apply(invariant.comp, first_value(invariant.current_values), second_value(invariant.current_values)),
    )
end

eval(
    invariant::RelationalInvariant{T,R},
    messages::DAGMessagesVector{SingleVariableMessage{T}},
) where {T<:DecisionValue,R<:RelationalOperator} =
    FloatFullMessage(!apply(invariant.comp, messages[1].value, messages[2].value))

function eval(
    invariant::RelationalInvariant{T,R},
    deltas::DAGMessagesVector{SingleVariableMoveDelta{T}},
) where {T<:DecisionValue,R<:RelationalOperator}
    new_values = deepcopy(invariant.current_values)
    for δ in deltas
        new_values[δ.index] = δ.new_value
    end
    return FloatDelta(
        !apply(invariant.comp, first_value(new_values), second_value(new_values)) -
        !apply(invariant.comp, first_value(invariant.current_values), second_value(invariant.current_values)),
    )
end

function commit!(
    invariant::RelationalInvariant{T,R},
    deltas::DAGMessagesVector{SingleVariableMoveDelta{T}},
) where {T<:DecisionValue,R<:RelationalOperator}
    for δ in deltas
        invariant.current_values[δ.index] = δ.new_value
    end
end

@testitem "init!(::RelationalInvariant{::EqOp})" begin
    invariant = JuLS.RelationalInvariant{JuLS.IntDecisionValue,JuLS.EqOp}()
    x = JuLS.SingleVariableMessage(3, JuLS.IntDecisionValue(12))
    y = JuLS.SingleVariableMessage(37, JuLS.IntDecisionValue(9))

    message = JuLS.init!(invariant, JuLS.DAGMessagesVector([x, y]))

    @test message.value == 1
    @test invariant.current_values[3].value == 12
    @test invariant.current_values[37].value == 9
end

@testitem "eval(::RelationalInvariant{::EqOp}, ::Delta)" begin
    invariant = JuLS.RelationalInvariant{JuLS.IntDecisionValue,JuLS.EqOp}()
    x = JuLS.SingleVariableMessage(3, JuLS.IntDecisionValue(12))
    y = JuLS.SingleVariableMessage(37, JuLS.IntDecisionValue(9))
    JuLS.init!(invariant, JuLS.DAGMessagesVector([x, y]))

    x1 = JuLS.SingleVariableMoveDelta(3, JuLS.IntDecisionValue(12), JuLS.IntDecisionValue(5))
    y1 = JuLS.SingleVariableMoveDelta(37, JuLS.IntDecisionValue(9), JuLS.IntDecisionValue(5))

    delta = JuLS.eval(invariant, JuLS.DAGMessagesVector([x1, y1]))
    @test delta.value == -1

    x2 = JuLS.SingleVariableMoveDelta(3, JuLS.IntDecisionValue(12), JuLS.IntDecisionValue(8))
    y2 = JuLS.SingleVariableMoveDelta(37, JuLS.IntDecisionValue(9), JuLS.IntDecisionValue(1))

    delta = JuLS.eval(invariant, JuLS.DAGMessagesVector([x2, y2]))
    @test delta.value == 0

    x3 = JuLS.SingleVariableMoveDelta(3, JuLS.IntDecisionValue(12), JuLS.IntDecisionValue(9))

    delta = JuLS.eval(invariant, JuLS.DAGMessagesVector([x3]))
    @test delta.value == -1
end

@testitem "commit!(::RelationalInvariant{::EqOp})" begin
    invariant = JuLS.RelationalInvariant{JuLS.IntDecisionValue,JuLS.EqOp}()
    x = JuLS.SingleVariableMessage(3, JuLS.IntDecisionValue(12))
    y = JuLS.SingleVariableMessage(37, JuLS.IntDecisionValue(9))
    JuLS.init!(invariant, JuLS.DAGMessagesVector([x, y]))

    x1 = JuLS.SingleVariableMoveDelta(3, JuLS.IntDecisionValue(12), JuLS.IntDecisionValue(5))
    y1 = JuLS.SingleVariableMoveDelta(37, JuLS.IntDecisionValue(9), JuLS.IntDecisionValue(5))

    JuLS.commit!(invariant, JuLS.DAGMessagesVector([x1, y1]))

    @test invariant.current_values[3].value == 5
    @test invariant.current_values[37].value == 5

    x2 = JuLS.SingleVariableMoveDelta(3, JuLS.IntDecisionValue(12), JuLS.IntDecisionValue(8))
    y2 = JuLS.SingleVariableMoveDelta(37, JuLS.IntDecisionValue(9), JuLS.IntDecisionValue(1))
    delta = JuLS.eval(invariant, JuLS.DAGMessagesVector([x2, y2]))
    @test delta.value == 1
end

@testitem "commit!(::RelationalInvariant{::NeOp})" begin
    invariant = JuLS.RelationalInvariant{JuLS.IntDecisionValue,JuLS.NeOp}()
    x = JuLS.SingleVariableMessage(3, JuLS.IntDecisionValue(12))
    y = JuLS.SingleVariableMessage(37, JuLS.IntDecisionValue(9))
    JuLS.init!(invariant, JuLS.DAGMessagesVector([x, y]))

    x1 = JuLS.SingleVariableMoveDelta(3, JuLS.IntDecisionValue(12), JuLS.IntDecisionValue(5))
    y1 = JuLS.SingleVariableMoveDelta(37, JuLS.IntDecisionValue(9), JuLS.IntDecisionValue(5))

    delta = JuLS.eval(invariant, JuLS.DAGMessagesVector([x1, y1]))
    @test delta.value == 1

    JuLS.commit!(invariant, JuLS.DAGMessagesVector([x1, y1]))

    delta = JuLS.eval(invariant, JuLS.DAGMessagesVector([x1, y1]))
    @test delta.value == 0
    @test invariant.current_values[3].value == 5
    @test invariant.current_values[37].value == 5

    x2 = JuLS.SingleVariableMoveDelta(3, JuLS.IntDecisionValue(5), JuLS.IntDecisionValue(8))
    y2 = JuLS.SingleVariableMoveDelta(37, JuLS.IntDecisionValue(5), JuLS.IntDecisionValue(1))
    delta = JuLS.eval(invariant, JuLS.DAGMessagesVector([x2, y2]))
    @test delta.value == -1
end