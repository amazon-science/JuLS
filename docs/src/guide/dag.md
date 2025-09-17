# DAG and Invariants

The Directed Acyclic Graph (DAG) is the core structure in JuLS that represents constraints and objectives of your optimization problem.

## What is an Invariant?

An invariant is a fixed relation between a set of input variables and a single output variable.

As a pedagogical example, an invariant I can represent the constraint z = x+ y, where the set of input variables would {x, y} and the output variable would be z.

An invariant can as well be a far more complex or even black-box relation.

## What is a DAG?

A DAG is a Directed Acyclic Graph of invariants. Through this graph, the optimization objective and constraints are represented.

To see how a DAG of invariants is constructed, you are encouraged to read the source code of our toy examples (for example the Knapsack).

The DAG uses message passing to:
- Propagate changes efficiently
- Maintain constraint consistency
- Compute objective values incrementally
