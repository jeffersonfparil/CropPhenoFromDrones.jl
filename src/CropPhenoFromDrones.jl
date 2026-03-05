module CropPhenoFromDrones

using CropPhenoFromDrones
using ArchGDAL # Base geospatial data core functionalities but I/O is too simplistic and will require a lot of boilerplate that's why we use Rasters.jl below
using Rasters # Raster I/O
using GeoDataFrames # Shapefile I/O and works with DataFrames.jl
using Random, StatsBase, Distributions
using CSV, DataFrames, Dates

include("simulate.jl")
export simulate_raster, simulate_shapes, simulate_layout

include("io.jl")
export load_raster,
    load_shapes_and_layout, output_fname, write_raster, write_shapes, write_layout

include("preprocess.jl")
calibrate_reflectance, align_modalities, generate_chm, mask_plots

include("phenotype.jl")
compute_indices, summarize_plot_features

end
