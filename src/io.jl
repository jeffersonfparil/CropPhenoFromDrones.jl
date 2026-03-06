# TODO: docstring and tests
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

"""
    write_raster(raster::Raster; path::String, overwrite::Bool=false)::String

Write a Raster to disk as a GeoTIFF and return the written filepath.
# Arguments
- raster::Raster is the raster to write; path::String is the desired output filepath; overwrite::Bool indicates whether to replace an existing file.
# Returns
- The full path of the written GeoTIFF as a String.
# Notes
- The function resolves the final filename using output_fname and writes the data with Rasters.write, so ensure the provided raster is compatible with Rasters.jl and that necessary file drivers are available.

# Example
```jldoctest; setup=:(using CropPhenoFromDrones, StatsBase, DataFrames, ArchGDAL, Rasters)
julia> raster = simulate_raster();

julia> write_raster(raster, path="simulated.tiff", overwrite=true) |> basename
"simulated.tiff"
```
"""
function write_raster(raster::Raster; path::String, overwrite::Bool = false)::String
    # raster = simulate_raster(); path = "simulated-red.tiff"; overwrite = true;
    fname_tiff = output_fname(path = path, overwrite = overwrite)
    Rasters.write(fname_tiff, raster, force = overwrite)
    fname_tiff
end

""" 
    write_shapes(df_shapes::DataFrame; path::String, overwrite::Bool=false)::String

Write a DataFrame of geometries and attributes to a shapefile and return the written filepath.
# Arguments
- df_shapes::DataFrame is the GeoDataFrame-like table of shapes and attributes to write; path::String is the desired output filepath; overwrite::Bool indicates whether to replace an existing file.
# Returns
- The full path of the written shapefile as a String.
# Notes
- The function uses output_fname to compute the destination filename and GeoDataFrames.write to perform the write, so ensure the DataFrame conforms to the expected geometry column and CRS conventions.

# Example
```jldoctest; setup=:(using CropPhenoFromDrones, StatsBase, DataFrames, ArchGDAL, Rasters)
julia> df_shapes = simulate_raster() |> x -> simulate_shapes(x);

julia> write_shapes(df_shapes, path="simulated.shp", overwrite=true) |> basename
"simulated.shp"
```
"""
function write_shapes(df_shapes::DataFrame; path::String, overwrite::Bool = false)::String
    # df_shapes = simulate_shapes(simulate_raster()); path = "simulated.shp"; overwrite = true;
    fname_shp = output_fname(path = path, overwrite = overwrite)
    GeoDataFrames.write(fname_shp, df_shapes)
    fname_shp
end

"""
    write_layout(df_layout::DataFrame; path::String, overwrite::Bool=false)::String

Write a layout DataFrame to a tab-separated values (TSV) file and return the written filepath.
# Arguments
- df_layout::DataFrame contains the layout rows and columns to serialize; path::String is the desired output filepath; overwrite::Bool indicates whether to replace an existing file.
# Returns
- The full path of the written TSV file as a String.
# Notes
- The function uses output_fname to resolve the filename and CSV.write with a tab delimiter to write the table, so ensure column types are serializable by CSV.

# Example
```jldoctest; setup=:(using CropPhenoFromDrones, StatsBase, DataFrames, ArchGDAL, Rasters)
julia> df_layout = simulate_raster() |> x -> simulate_shapes(x) |> x -> simulate_layout(x);

julia> write_layout(df_layout, path="simulated-layout.tsv", overwrite=true) |> basename
"simulated-layout.tsv"
```
"""
function write_layout(df_layout::DataFrame; path::String, overwrite::Bool = false)::String
    # df_layout = simulate_layout(simulate_shapes(simulate_raster())); path = "simulated-layout.tsv"; overwrite = true;
    fname_tsv = output_fname(path = path, overwrite = overwrite)
    CSV.write(fname_tsv, df_layout, delim = "\t")
    fname_tsv
end

"""
    load_raster(path::String)::Raster

Load a raster from the file at the specified path and return a Raster object.

# Argument
- path::String: Path to the raster file to be loaded.

# Returns
- Raster: A Raster instance constructed from the file at path.

# Throws
- an error if the file does not exist or cannot be opened.

# Notes
- This function is a thin wrapper around the Raster constructor and performs no additional validation or processing.

# Example
```jldoctest; setup=:(using CropPhenoFromDrones, StatsBase, DataFrames, ArchGDAL, Rasters)
julia> raster = simulate_raster();

julia> fname_raster = write_raster(raster, path="simulated.tiff", overwrite=true);

julia> raster_reloaded = load_raster(fname_raster);

julia> raster_reloaded == raster
true
```
"""
function load_raster(path::String)::Raster
    Raster(path)
end

"""
    load_shapes_merge_layout(
        fname_shapes::String;
        fname_layout::Union{Nothing,String}=nothing,
        id::String="id",
        name::String="name",
        remove_rows_with_missing::Bool=true,
    )::DataFrame

Load shapes from a geospatial file and optionally merge them with a layout table by id.

# Arguments
- fname_shapes::String: path to the shapes file that GeoDataFrames.read can consume, typically a Shapefile.
- fname_layout::Union{Nothing,String}=nothing: optional path to a CSV/TSV layout table to merge with the shapes; pass nothing to skip merging.
- id::String="id": column name used as the join key in both the shapes and layout tables.
- name::String="name": column name in the layout containing entry or genotype names that will be renamed to "name" to satisfy Shapefile field-length limits.
- remove_rows_with_missing::Bool=true: if true, disallowmissing! is applied to the merged DataFrame to remove or convert missing values following the join.

# Returns
- DataFrame containing the shapes read from fname_shapes if fname_layout is nothing, otherwise the left-joined DataFrame of shapes and layout on the id column with layout fields appended.

# Errors
- Throws an ErrorException if the id column is absent in the shapes file.
- Throws an ErrorException if either the id or the specified name column is absent in the layout file when a layout file is provided.

# Behaviour and notes
- The function uses GeoDataFrames.read to read geospatial shapes and CSV.read to read the layout table.
- When a layout is provided the specified name column is renamed to "name" because Shapefile field names are limited in length.
- All columns in the layout that contain AbstractString values are converted to plain String to improve Shapefile compatibility.
- The merge is a left join on the id column and makeunique=true is used to avoid duplicate column names.
- If remove_rows_with_missing is true disallowmissing! is called on the merged DataFrame which may convert missing to non-missing where possible or error if conversion is not possible.

# Example
```jldoctest; setup=:(using CropPhenoFromDrones, StatsBase, DataFrames, ArchGDAL, Rasters)
julia> df_shapes = simulate_raster() |> x -> simulate_shapes(x);

julia> df_layout = simulate_layout(df_shapes);

julia> fname_shapes = write_shapes(df_shapes, path="simulated.shp", overwrite=true);

julia> fname_layout = write_layout(df_layout, path="simulated-layout.tsv", overwrite=true);

julia> df_shapes_reloaded = load_shapes_merge_layout(fname_shapes);

julia> df_shapes_reloaded == df_shapes
true

julia> df_shapes_merged_layout = load_shapes_merge_layout(fname_shapes, fname_layout=fname_layout, id="id", name="name");

julia> names(df_shapes_merged_layout) == sort(unique(vcat(names(df_shapes), names(df_layout))))
true
```
"""
function load_shapes_merge_layout(
    fname_shapes::String;
    fname_layout::Union{Nothing,String} = nothing,
    id::String = "id",
    name::String = "name",
    remove_rows_with_missing::Bool = true,
)::DataFrame
    # df_shapes = simulate_raster() |> x -> simulate_shapes(x)
    # df_layout = simulate_layout(df_shapes)
    # fname_shapes::String = write_shapes(df_shapes, path="simulated.shp", overwrite=true)
    # fname_layout::Union{Nothing,String} = write_layout(df_layout, path="simulated-layout.tsv", overwrite=true)
    # # fname_layout::Union{Nothing,String} = nothing
    # id::String = "id"
    # name::Union{Nothing,String} = "name"
    # remove_rows_with_missing::Bool = true
    #############################################
    df_shapes = GeoDataFrames.read(fname_shapes)
    if id ∉ names(df_shapes)
        throw(ErrorException("The id column (\"$id\") is absent in \"$fname_shapes\"."))
    end
    df_layout = if isnothing(fname_layout)
        nothing
    else
        df_layout = CSV.read(fname_layout, DataFrames.DataFrame)
        if (id ∉ names(df_layout)) || (name ∉ names(df_layout))
            throw(
                ErrorException(
                    "Columns \"$id\" and/or \"$name\" are not found in \"$fname_layout\".",
                ),
            )
        end
        # Rename the entry or genotype names to simply "name" because Shapefile specs limit the number of characters of the fields to just 10
        rename!(df_layout, name => "name")
        # Set all AbstractString into simply String for compatibility with Shapefile specs
        for f in names(df_layout)
            # f = names(df_layout)[1]
            bool::Bool = false
            for x in df_layout[!, f]
                if x isa AbstractString
                    bool = true
                    break
                end
            end
            if bool
                df_layout[!, f] = String.(df_layout[!, f])
            end
        end
        df_layout
    end
    if isnothing(df_layout)
        return df_shapes
    else
        df_shapes_merged_layout =
            leftjoin(df_shapes, df_layout, on = [:id], makeunique = true)
        remove_rows_with_missing ? disallowmissing!(df_shapes_merged_layout) : nothing
        # Sort columns alphabetical to be consistent with Shapefile specs
        select!(df_shapes_merged_layout, sort(propertynames(df_shapes_merged_layout)))
        return df_shapes_merged_layout
    end
end
