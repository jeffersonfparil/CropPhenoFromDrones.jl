module CropPhenoFromDrones

using CropPhenoFromDrones
using ArchGDAL # Base geospatial data core functionalities but I/O is too simplistic and will require a lot of boilerplate that's why we use Rasters.jl below
using Rasters # Raster I/O
using GeoDataFrames # Shapefile I/O and works with DataFrames.jl
using Random, StatsBase, Distributions
using CSV, DataFrames, Dates
using ProgressMeter
using CairoMakie, GeoMakie

include("io.jl")
export Data
export output_fname, write_raster, write_shapes, write_phenotypes, write_data
export load_raster, load_shapes_phenotypes, check_dimensions, load_data

include("simulate.jl")
export simulate_raster, simulate_shapes, simulate_phenotypes, simulate_data

include("phenotype.jl")
export compute_indices, summarize_plot_features

end
