using CropPhenoFromDrones
using ArchGDAL # Base geospatial data core functionalities but I/O is too simplistic and will require a lot of boilerplate that's why we use Rasters.jl below
using Rasters # Raster I/O
using GeoDataFrames # Shapefile I/O and works with DataFrames.jl
using Random, StatsBase, Distributions
using CSV, DataFrames, Dates

using JuliaFormatter
format(".")
