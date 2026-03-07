"""
    simulate_raster(;
        lon_ini::Float64=25.0,
        lon_fin::Float64=30.0,
        lon_step::Float64=1.0,
        lat_ini::Float64=25.0,
        lat_fin::Float64=30.0,
        lat_step::Float64=1.0,
        EPSG_code::Int64=32754, # used in the Fan's 2023 GeoRaster data
        n_time_points::Int64=1,
        μ::Float64=0.0,
        σ::Float64=0.0,
        seed::Int64=42,
    )::Raster

Create a synthetic Raster with spatial (longitude, latitude) dimensions and an optional time dimension. Raster cell values are sampled from a Normal distribution N(μ, σ) and the returned raster is assigned the coordinate reference system given by `EPSG(EPSG_code)` ([see spatial reference list](https://spatialreference.org/ref/epsg/)).

# Arguments
- `lon_ini::Float64=25.0`: starting longitude (inclusive).
- `lon_fin::Float64=30.0`: ending longitude (inclusive).
- `lon_step::Float64=1.0`: spacing between longitude samples.
- `lat_ini::Float64=25.0`: starting latitude (inclusive).
- `lat_fin::Float64=30.0`: ending latitude (inclusive).
- `lat_step::Float64=1.0`: spacing between latitude samples.
- `EPSG_code::Int64=32754`: EPSG code used to set the raster CRS.
- `n_time_points::Int64=1`: number of time slices requested. If > 1 a time dimension is added; the implementation creates a time index containing `Dates.now()` (a single timestamp) for the time dimension.
- `μ::Float64=0.0`: mean of the Normal distribution used to generate raster values.
- `σ::Float64=1.0`: standard deviation of the Normal distribution.
- `seed::Int64=42`: integer seed used with `Random.seed!` to make sampling reproducible.

# Returns
- `Raster`: a Rasters.Raster object with dimensions corresponding to the specified longitude and latitude ranges. If `n_time_points > 1`, the raster has dimensions (lon, lat, time); otherwise it has (lon, lat).

# Notes
- Longitude and latitude coordinates are generated using Julia range notation `lon_ini:lon_step:lon_fin` and `lat_ini:lat_step:lat_fin`, so end values are included when they fall on the step sequence. Invalid steps (e.g., zero) or ranges that produce empty coordinate vectors will raise an error.
- Values are drawn with `rand(N, ...)` where `N = Distributions.Normal(μ, σ)`. Set `seed` for deterministic output across calls.
- When `n_time_points > 1` the function currently attaches a single timestamp (`Dates.now()`) as the time index; the length of the time dimension in the returned raster may therefore be 1 even if `n_time_points` is larger. (If you require multiple distinct time slices, generate or supply an explicit time index.)

# Examples
```jldoctest; setup=:(using CropPhenoFromDrones, StatsBase, DataFrames, ArchGDAL, Rasters)
julia> raster_1 = simulate_raster();

julia> raster_2 = simulate_raster();

julia> raster_3 = simulate_raster(lon_ini = 10.0);

julia> abs(mean(raster_1.data)) < 0.5
true

julia> abs(1.00 - std(raster_1.data)) < 0.5
true

julia> raster_1 == raster_2
true

julia> raster_1 == raster_3
false

julia> prod(size(raster_1.data)) < prod(size(raster_3.data))
true
```
"""
function simulate_raster(;
    lon_ini::Float64 = 25.0,
    lon_fin::Float64 = 30.0,
    lon_step::Float64 = 1.0,
    lat_ini::Float64 = 25.0,
    lat_fin::Float64 = 30.0,
    lat_step::Float64 = 1.0,
    EPSG_code::Int64 = 32754, # used in the Fan's 2023 GeoRaster data
    n_time_points::Int64 = 1,
    μ::Float64 = 0.0,
    σ::Float64 = 1.0,
    seed::Int64 = 42,
)::Raster
    # lon_ini::Float64=25.0; lon_fin::Float64=30.0; lon_step::Float64=1.0; lat_ini::Float64=25.0; lat_fin::Float64=30.0; lat_step::Float64=1.0; EPSG_code::Int64=32754; n_time_points::Int64=1; μ::Float64 = 0.0; σ::Float64 = 1.0; seed::Int64 = 42
    lon, lat =
        Rasters.X(lon_ini:lon_step:lon_fin), reverse(Rasters.Y(lat_ini:lat_step:lat_fin)) # reversing Y for north-up coordinates
    N = Distributions.Normal(μ, σ)
    Random.seed!(seed)
    raster = if n_time_points > 1
        ti = Ti([Dates.now()])
        Rasters.Raster(rand(N, lon, lat, ti), crs = EPSG(EPSG_code))
    else
        Rasters.Raster(rand(N, lon, lat), crs = EPSG(EPSG_code))
    end
    return raster
end

"""
    simulate_shapes(raster::Raster)::DataFrame

Construct polygon geometries for each cell of a raster and return a DataFrame mapping plot ids to polygon geometries.

# Arguments
- raster::Raster: A Rasters.jl-compatible raster object with X and Y dimensions and an associated coordinate reference system (CRS); the function uses the raster grid coordinates to build polygons for each cell.

# Returns
- DataFrame: A DataFrame with columns sorted alphabetically. These columns are `id` (String) and `geometry` (ArchGDAL polygon objects) representing per-cell polygons; where the CRS of the raster is assigned to the returned DataFrame via GeoDataFrames.setcrs!.

# Details
- Each polygon corresponds to a rectangular cell formed by consecutive X and Y grid coordinates derived from dims(raster, Rasters.X).val and dims(raster, Rasters.Y).val
- Cell corners are ordered to close the polygon
- IDs are generated as "plot1", "plot2", ...
- ArchGDAL.createpolygon is used to construct geometries

# Notes
The function assumes a regular raster grid, presence of ArchGDAL and GeoDataFrames functionality, and that the geometry column is named `geometry` (Shapefile exports impose a 10-character column name limit).

# Examples
```jldoctest; setup=:(using CropPhenoFromDrones, StatsBase, DataFrames, ArchGDAL, Rasters)
julia> raster = simulate_raster();

julia> df_shapes = simulate_shapes(raster);

julia> prod(size(raster.data) .- 1) == nrow(df_shapes)
true

julia> names(df_shapes) == sort(["id", "geometry"])
true

julia> typeof(df_shapes.id) == Vector{String}
true

julia> typeof(df_shapes.geometry) == Vector{ArchGDAL.IGeometry{ArchGDAL.wkbPolygon}}
true
```
"""
function simulate_shapes(raster::Raster)::DataFrame
    # raster::Raster = simulate_raster()
    coordinates::Vector{Vector{Tuple{Float64,Float64}}} = []
    xs = collect(dims(raster, Rasters.X).val)
    ys = collect(dims(raster, Rasters.Y).val)
    for i = 1:(length(xs)-1)
        for j = 1:(length(ys)-1)
            polygon = []
            push!(polygon, (xs[i], ys[j]))
            push!(polygon, (xs[i], ys[j+1]))
            push!(polygon, (xs[i+1], ys[j+1]))
            push!(polygon, (xs[i+1], ys[j]))
            push!(polygon, (xs[i], ys[j]))
            push!(coordinates, reverse(polygon)) # reversing so that we are consistent with `simulate_raster()` above, and default North-up orientation
        end
    end
    polygons = ArchGDAL.createpolygon.(coordinates)
    df_shapes = DataFrame(id = string.("plot", 1:length(polygons)), geometry = polygons)
    # Note: set geometry column only required if the column is not named "geometry" , also note that column names are restricted to 10 characters in the Shapefile format specs
    # GeoDataFrames.setgeometrycolumn!(df_shapes, :geom) 
    # Set coordinate reference system
    GeoDataFrames.setcrs!(df_shapes, crs(raster))
    # Sort columns alphabetical to be consistent with Shapefile specs
    select!(df_shapes, sort(propertynames(df_shapes)))
    return df_shapes
end

"""
    simulate_layout(df_shapes::DataFrame; max_replications::Int64 = 2)::DataFrame

Generate a simple plot/layout table from a spatial DataFrame that contains an `id` field and an `geometry` field (ArchGDAL geometries). The function computes a representative centre (X, Y) for each geometry and assembles a layout DataFrame with one row per input feature.

Arguments
- `df_shapes::DataFrame`: A spatial DataFrame containing at least the columns `id` and `geometry` (ArchGDAL polygon-like geometries). The implementation expects polygon-like geometries where points at indices 0 and 2 represent opposite corners (used to compute the centre).
- `max_replications::Int64=2` (optional): Maximum number of replications per experimental unit. This value is used to compute the number of unique "entry" names; when `max_replications > 1` the function will create fewer unique entry labels and assign them across the rows (names are sampled for assignment).

Returns
- `DataFrame`: A tabular layout with columns `id` (copied from the input DataFrame), `name` (an assigned entry label, e.g. "entry_1", "entry_2", ...), `row` (X coordinate of the computed feature centre), `column` (Y coordinate of the computed feature centre), and `block` (a block identifier, currently the fixed string "block_1").

Errors
- Throws an ErrorException if either the `id` or `geometry` columns are missing from the input DataFrame.
- Throws an ErrorException if `max_replications < 1`.

Notes
- The centre is computed as the midpoint between the geometry points at indices 0 and 2, so the geometry must be structured such that those indices correspond to opposite corners of the shape (typical for rectangular/axis-aligned polygons).
- The `name` column is generated by sampling labels of the form "entry_i". To obtain deterministic names set the random seed prior to calling or post-process the `name` column.
- The `block` column is currently a single constant value ("block_1"); extend as needed for multi-block experiments.

# Examples
```jldoctest; setup=:(using CropPhenoFromDrones, StatsBase, DataFrames, ArchGDAL, Rasters)
julia> raster = simulate_raster();

julia> df_shapes = simulate_shapes(raster);

julia> df_layout = simulate_layout(df_shapes, max_replications=3);

julia> nrow(df_shapes) == nrow(df_layout)
true

julia> maximum(values(countmap(df_layout.name)))
3
```
"""
function simulate_layout(df_shapes::DataFrame; max_replications::Int64 = 2)::DataFrame
    # df_shapes::DataFrame = simulate_raster() |> x -> simulate_shapes(x); max_replications::Int64 = 2
    if ("id" ∉ names(df_shapes)) || ("geometry" ∉ names(df_shapes))
        throw(
            ErrorException(
                "The input Shapefile DataFrame is missing the `id` and/or `geometry` field/s!",
            ),
        )
    end
    if max_replications < 1
        throw(ErrorException("Cannot have `maximum_replications < 1`!"))
    end
    row::Vector{Float64} = []
    column::Vector{Float64} = []
    for i = 1:nrow(df_shapes)
        # i = 1
        geom = ArchGDAL.getgeom.(df_shapes.geometry, 0)[i]
        p00 = ArchGDAL.getpoint(geom, 0)
        p11 = ArchGDAL.getpoint(geom, 2)
        centre = p00 .+ (p11 .- p00) ./ 2
        push!(row, centre[1])
        push!(column, centre[2])
    end
    n = Int64(ceil(nrow(df_shapes) / max_replications))
    df_layout = DataFrame(
        id = df_shapes.id,
        name = repeat(string.("entry_", 1:n), max_replications)[1:nrow(df_shapes)],
        row = row,
        column = column,
        block = "block_1",
    )
    return df_layout
end

# TODO: add docstring
function simulate_phenotypes(df_layout::DataFrame; n_traits::Int64=1)::DataFrame
    # df_layout = simulate_raster() |> x -> simulate_shapes(x) |> x -> simulate_layout(x); n_traits::Int64=1
    df_phenotypes = deepcopy(df_layout)
    for i in 1:n_traits
        trait_name = "trait_$i"
        df_phenotypes[!, trait_name] = randn(nrow(df_layout))
    end
    return df_phenotypes
end

# TODO: update docstring
"""
    simulate(;
        lon_ini::Float64 = 25.0,
        lon_fin::Float64 = 30.0,
        lon_step::Float64 = 1.0,
        lat_ini::Float64 = 25.0,
        lat_fin::Float64 = 30.0,
        lat_step::Float64 = 1.0,
        EPSG_code::Int64 = 32754,
        n_time_points::Int64 = 1,
        μ::Float64 = 0.0,
        σ::Float64 = 1.0,
        bands::Vector{String} = ["red", "green", "blue", "nir"],
        save::Bool = true,
        fname_prefix::String = "simulated",
        overwrite::Bool = false,
        seed::Int64 = 42,
        verbose::Bool = false,
    )::Tuple{Dict{String,Raster},DataFrame,DataFrame,Union{Nothing,Vector{String}}}

Create synthetic multi-band raster data and associated vector outputs for a simple simulated field experiment.

This function:
- simulates one Raster per requested band over a regular lon/lat grid (projected to the supplied EPSG),
- derives per-cell polygon geometries (shapefile-like) from the first simulated band,
- derives a simple layout table mapping plot ids to entry names and spatial centres,
- optionally writes GeoTIFFs (one per band), the shapefile (with auxiliary files), and a layout TSV to disk.

# Arguments
- lon_ini, lon_fin, lon_step, lat_ini, lat_fin, lat_step: grid extent and spacing (ranges use Julia `start:step:stop` semantics).
- EPSG_code: integer EPSG code used to set the raster CRS.
- n_time_points: number of temporal layers per band (see notes below).
- μ, σ: Normal(μ, σ) parameters used to generate pixel values.
- bands: names of bands to simulate; returned as keys in the channels Dict.
- save: when true, write outputs to disk and return a Vector of written file paths; when false, return nothing for the filenames element.
- fname_prefix: prefix used for output filenames when saving.
- overwrite: allow overwriting existing files when saving.
- seed: integer seed passed to simulate_raster for reproducible random draws.
- verbose: when true, print progress messages and show progress meters.

# Returns
A 4-tuple:
1. Dict{String,Raster} — mapping band name to the simulated Rasters.Raster object.
2. DataFrame — per-cell polygon table (columns include `id` and `geometry`).
3. DataFrame — layout table mapping `id` to `name`, `row`, `column`, `block`.
4. Union{Nothing,Vector{String}} — when `save == true` a Vector of file paths written; otherwise `nothing`.

# Notes
- Shapes and layout are derived from the first band in `bands`. Ensure the first band is the one you want to use for geometry/layout derivation.
- When `save == true` the function writes one GeoTIFF per band, the shapefile components (`.shp`, `.shx`, `.prj`, `.dbf`) and a layout TSV file; the returned filename vector lists the produced files.
- The `seed` value is passed unchanged to each call of `simulate_raster`. If you require different random draws across bands, vary `seed` per band before calling or change the call pattern.
- `n_time_points > 1` triggers creation of a time axis in the simulated rasters; note that the simple helper currently attaches a single timestamp (see simulate_raster docs) so the effective number of distinct time slices may be limited.
- Use `verbose=true` to observe progress bars (requires ProgressMeter).

# Examples
```jldoctest; setup=:(using CropPhenoFromDrones, StatsBase, DataFrames, ArchGDAL, Rasters)
julia> channels, df_shapes, df_layout, df_phenotypes, fnames = simulate(overwrite=true);

julia> first(channels)[end] isa Raster
true

julia> prod(size(first(channels)[end].data) .- 1) == nrow(df_shapes)
true

julia> nrow(df_shapes) == nrow(df_layout)
true

julia> length(fnames) == 10
true

julia> sum(.!isnothing.(match.(Regex(".tiff"), fnames))) == 4
true

julia> sum(.!isnothing.(match.(Regex(".shp|.shx|.prj|.dbf"), fnames))) == 4
true

julia> sum(.!isnothing.(match.(Regex("-layout.tsv"), fnames))) == 1
true
```
"""
function simulate(;
    lon_ini::Float64 = 25.0,
    lon_fin::Float64 = 30.0,
    lon_step::Float64 = 1.0,
    lat_ini::Float64 = 25.0,
    lat_fin::Float64 = 30.0,
    lat_step::Float64 = 1.0,
    EPSG_code::Int64 = 32754, # used in the Fan's 2023 GeoRaster data
    n_time_points::Int64 = 1,
    μ::Float64 = 0.0,
    σ::Float64 = 1.0,
    bands::Vector{String} = ["red", "green", "blue", "nir"],
    n_traits::Int64 = 1,
    save::Bool = true,
    fname_prefix::String = "simulated",
    overwrite::Bool = false,
    seed::Int64 = 42,
    verbose::Bool = false,
)::Tuple{Dict{String,Raster},DataFrame,DataFrame,DataFrame,Union{Nothing,Vector{String}}}
    # lon_ini::Float64=25.0; lon_fin::Float64=30.0; lon_step::Float64=1.0; lat_ini::Float64=25.0; lat_fin::Float64=30.0; lat_step::Float64=1.0; EPSG_code::Int64=32754; n_time_points::Int64=1; μ::Float64 = 0.0; σ::Float64 = 1.0; seed::Int64 = 42; bands::Vector{String}=["red", "green", "blue", "nir"]; save::Bool = true; fname_prefix::String = "simulated"; overwrite::Bool = true; seed::Int64 = 42; verbose::Bool=false
    pb = verbose ? ProgressMeter.Progress(length(bands), "Simulating the raster") : nothing
    channels::Dict{String,Raster} = Dict()
    for id in bands
        channels[id] = simulate_raster(
            lon_ini = lon_ini,
            lon_fin = lon_fin,
            lon_step = lon_step,
            lat_ini = lat_ini,
            lat_fin = lat_fin,
            lat_step = lat_step,
            EPSG_code = EPSG_code,
            n_time_points = n_time_points,
            μ = μ,
            σ = σ,
            seed = seed,
        )
        verbose ? ProgressMeter.next!(pb) : nothing
    end
    verbose ? ProgressMeter.finish!(pb) : nothing
    verbose ? println("Simulating shapes (plot ROIs)...") : nothing
    df_shapes = simulate_shapes(channels[bands[1]])
    verbose ? println("Simulating layout...") : nothing
    df_layout = simulate_layout(df_shapes)
    verbose ? println("Simulating phenotypes...") : nothing
    df_phenotypes = simulate_phenotypes(df_layout, n_traits=n_traits)
    # Save individual tiffs per band (GeRasters) and also the shapes (GeoVectors) and layouts (field layout information mapping the entry or genotype or cultivar names with the plot ids in the Shapefile)
    fnames::Union{Nothing,Vector{String}} = if save
        pb =
            verbose ?
            ProgressMeter.Progress(
                length(bands) + 2,
                "Saving the raster/s, shapes, layout, and phenotypes...",
            ) : nothing
        fnames = []
        for (channel, raster) in channels
            fname_tiff = write_raster(
                raster,
                path = "$fname_prefix-$channel.tiff",
                overwrite = overwrite,
            )
            push!(fnames, fname_tiff)
            verbose ? ProgressMeter.next!(pb) : nothing
        end
        fname_shp =
            write_shapes(df_shapes, path = "$fname_prefix.shp", overwrite = overwrite)
        for suffix in [".shp", ".shx", ".prj", ".dbf"]
            push!(fnames, replace(fname_shp, ".shp" => suffix))
        end
        verbose ? ProgressMeter.next!(pb) : nothing
        fname_tsv = write_layout(
            df_layout,
            path = "$fname_prefix-layout.tsv",
            overwrite = overwrite,
        )
        verbose ? ProgressMeter.next!(pb) : nothing
        push!(fnames, fname_tsv)
        verbose ? ProgressMeter.next!(pb) : nothing
        fname_phenotypes = let
            fname_phenotypes = "$fname_prefix-phenotypes.tsv"
            CSV.write(fname_phenotypes, df_phenotypes)
            fname_phenotypes
        end
        push!(fnames, fname_phenotypes)
        verbose ? ProgressMeter.finish!(pb) : nothing
        fnames
    else
        nothing
    end
    # Output
    (channels, df_shapes, df_layout, df_phenotypes, fnames)
end
