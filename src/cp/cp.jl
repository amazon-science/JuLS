# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

abstract type CPConstraint end
abstract type AbstractVariableSelection end
abstract type AbstractValueSelection end

include("trailer.jl")
include("variables/variables.jl")
include("core/core.jl")
include("variableselection/variableselection.jl")
include("valueselection/valueselection.jl")
include("constraints/constraints.jl")
include("model/model.jl")
include("builder/builder.jl")