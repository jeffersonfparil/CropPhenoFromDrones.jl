using CropPhenoFromDrones
using Documenter

DocMeta.setdocmeta!(CropPhenoFromDrones, :DocTestSetup, :(using CropPhenoFromDrones); recursive=true)

makedocs(;
    modules=[CropPhenoFromDrones],
    authors="jeffersonparil@gmail.com",
    sitename="CropPhenoFromDrones.jl",
    format=Documenter.HTML(;
        canonical="https://CropPhenoFromDrones.github.io/CropPhenoFromDrones.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/CropPhenoFromDrones/CropPhenoFromDrones.jl",
    devbranch="main",
)
