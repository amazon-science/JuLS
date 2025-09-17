# DAG and Invariants

The Directed Acyclic Graph (DAG) is the core structure in JuLS that represents constraints and objectives of your optimization problem.

## What is a DAG?

A DAG in JuLS is a computational graph where:
- **Nodes** represent variables, constants, or computed values
- **Edges** represent dependencies between computations
- **Invariants** are computational units that maintain consistency

## Basic Concepts

### Invariants

Invariants are the building blocks of the DAG. They represent:
- Constraints (e.g., capacity limits, adjacency requirements)
- Objectives (e.g., minimize cost, maximize value)
- Intermediate computations (e.g., sums, products)

### Message Passing

The DAG uses message passing to:
- Propagate changes efficiently
- Maintain constraint consistency
- Compute objective values incrementally
