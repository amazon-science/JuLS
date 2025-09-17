using Documenter
using JuLS

makedocs(
    sitename = "JuLS.jl",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://amazon-science.github.io/JuLS.jl/stable/",
        assets = String[],
    ),
    modules = [JuLS],
    pages = [
        "Home" => "index.md",
        "Getting Started" => "getting_started.md",
        "User Guide" => [
            "Creating Experiments" => "guide/experiments.md",
            "DAG and Invariants" => "guide/dag.md",
            "Heuristics" => "guide/heuristics.md",
            "Constraint Programming" => "guide/cp.md",
        ],
        "Examples" => [
            "Knapsack Problem" => "examples/knapsack.md",
            "Traveling Salesman Problem" => "examples/tsp.md",
            "Graph Coloring Problem" => "examples/graph_coloring.md",
        ],
        "API Reference" => [
            "Model" => "api/model.md",
            "DAG" => "api/dag.md",
            "Constraints" => "api/constraints.md",
            "Heuristics" => "api/heuristics.md",
            "Experiments" => "api/experiments.md",
        ],
    ],
    checkdocs = :exports,
)

deploydocs(
    repo = "github.com/amazon-science/JuLS.git",
    devbranch = "main",
)
