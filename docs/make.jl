using MLUtils
using MLCore
using Documenter

# Copy the README to the home page in docs, to avoid duplication.
readme = readlines(joinpath(@__DIR__, "..", "README.md"))

open(joinpath(@__DIR__, "src/index.md"), "w") do f
    for l in readme
        println(f, l)
    end
end

DocMeta.setdocmeta!(MLUtils, :DocTestSetup, :(using MLUtils); recursive=true)
DocMeta.setdocmeta!(MLCore, :DocTestSetup, :(using MLCore); recursive=true)

makedocs(;
    modules=[MLUtils, MLCore],
    sitename = "MLUtils.jl",
    pages = ["Home" => "index.md",
             "Guide" => "guide.md",
             "API" => "api.md"],
)

rm(joinpath(@__DIR__, "src/index.md"))

deploydocs(repo="github.com/JuliaML/MLUtils.jl.git",  devbranch="main")
