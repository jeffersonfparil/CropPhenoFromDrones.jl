function load_raster(path::String)::Raster
    Raster(path)
end
function load_shapes_and_layout(;
    fname_shapes::String,
    fname_layout::String,
)::Tuple{DataFrame,String}
    # dir_tmp = "/group/pasture/forages/Ryegrass/STR/NUE_WUE_merged_2022_2025/phenotypes/growth_rates/preprocessing_in_an_attempt_to_squeeze_in_pseudo_reps_per_flight/"
    # fname_shapes = joinpath(dir_tmp, "2023-10-23_STR-NUE-WUE-2023_plot.shp")
    # fname_layout = joinpath(dir_tmp, "2023-09-05_STR-NUE-WUE-plot_layout.txt")
    df_shapes = GeoDataFrames.read(fname_shapes)
    GeoDataFrames.getcrs(df)
    df_layout = CSV.read(fname_layout, DataFrames.DataFrame)
    select!(df_layout, [:id, :population_id])
    rename!(df_layout, "population_id" => "name") # rename to just "name" because Spahefile specs limit the number of characters of the fields to just 10
    df_layout.name .= String.(df_layout.name)
    S = leftjoin(df_shapes, df_layout, on = [:id], makeunique = true)
    disallowmissing!(S)
    fname_shapes_updated = replace(fname_shapes, r".shp$" => "-updated.shp")
    GeoDataFrames.write(fname_shapes_updated, S)
    (S, fname_shapes_updated)
end

function output_fname(;
    path::String = "",
    default_prefix::String = "simulated",
    extension_name::String = "tiff",
    overwrite::Bool = false,
)::String
    # path::String=""; default_prefix::String="simulated"; extension_name::String="tiff"; overwrite::Bool=false; verbose::Bool=false
    if path == ""
        joinpath(pwd(), "$default_prefix-$(Dates.now()).$extension_name")
    else
        dir = if dirname(path) == ""
            pwd()
        else
            if !isdir(dirname(path))
                throw(ErrorException("Directory `$(dirname(path))` does not exist!"))
            else
                dirname(path)
            end
        end
        if isfile(path) && !overwrite
            throw(
                ErrorException(
                    "$path exists! Please set `overwrite=true` if you wish to overwrite the existing file.",
                ),
            )
        else
            isfile(path) ? rm(path) : nothing
            joinpath(dir, basename(path))
        end
    end
end

function write_raster(raster::Raster; path::String, overwrite::Bool = false)::String
    # raster = simulate_raster(); path = "simulated-red.tiff"; overwrite = true;
    fname_tiff = output_fname(path = path, overwrite = overwrite)
    Rasters.write(fname_tiff, raster, force = overwrite)
    fname_tiff
end

function write_shapes(df_shapes::DataFrame; path::String, overwrite::Bool = false)::String
    # df_shapes = simulate_shapes(simulate_raster()); path = "simulated.shp"; overwrite = true;
    fname_shp = output_fname(path = path, overwrite = overwrite)
    GeoDataFrames.write(fname_shp, df_shapes)
    fname_shp
end

function write_layout(df_layout::DataFrame; path::String, overwrite::Bool = false)::String
    # df_layout = simulate_layout(simulate_shapes(simulate_raster())); path = "simulated-layout.tsv"; overwrite = true;
    fname_tsv = output_fname(path = path, overwrite = overwrite)
    CSV.write(fname_tsv, df_layout, delim = "\t")
    fname_tsv
end


# function write_raster_and_shapefiles(
#     raster::Raster{Float64},
#     df::DataFrame,
#     fname_prefix::String;
#     overwrite::Bool = false,
# )::Vector{String}
#     # raster::Raster{Float64} = simulate_raster(); df::DataFrame = simulate_shapefiles(raster); fname_prefix::String="simulated"; overwrite::Bool=true
#     fnames_tiff = output_fname(path = "$fname_prefix.tiff", overwrite = overwrite)
#     fnames_shp = output_fname(path = "$fname_prefix.shp", overwrite = overwrite)
#     Rasters.write(fnames_tiff, raster, force = overwrite)
#     GeoDataFrames.write(fnames_shp, df)
#     output = let
#         output = readdir()
#         output[.!isnothing.(match.(Regex("^$fname_prefix\\."), output))]
#     end
#     output
# end

# fname_shapes, fname_layout, fnames_tiffs = let
#     dir = "/group/pasture/forages/Ryegrass/STR/NUE_WUE_merged_2022_2025/phenotypes/growth_rates/preprocessing_in_an_attempt_to_squeeze_in_pseudo_reps_per_flight/"
#     fname_shapes = joinpath(dir, "2023-10-23_STR-NUE-WUE-2023_plot.shp")
#     fname_layout = joinpath(dir, "2023-09-05_STR-NUE-WUE-plot_layout.txt")
#     fnames = readdir(dir)
#     filter!(x -> !isnothing(match(r".tif$", x)), fnames)
#     fnames_tiffs = joinpath.(dir, fnames)
#     (fname_shapes, fname_layout, fnames_tiffs)
# end

# df_rois, fname_shapes_updated = parse_roi_geometries(fname_shapes=fname_shapes, fname_layout=fname_layout)

# rasters_per_channel::Dict{String,Dict{String,Any}} = Dict()
# for fname_tiff in fnames_tiffs
#     # fname_tiff = fnames_tiffs[1]
#     key = basename(fname_tiff)
#     raster = Raster(fname_tiff)
#     rasters_per_channel[key] = Dict()
#     for (i, id) in enumerate(df_rois.id)
#         # i = 1; id = D.is[i]
#         rasters_per_channel[key][id] = crop(raster; to=df_rois.geometry[i])
#     end
# end

# # TODO: extract RGB + NIR data to start extracting metrics
# rasters_rgbn = Dict(
#     "red" => Dict(),
#     "green" => Dict(),
#     "blue" => Dict(),
#     "nir" => Dict(),
# )


# Calculate NDVI (NDVI = (nir - red) / (nir + red))
