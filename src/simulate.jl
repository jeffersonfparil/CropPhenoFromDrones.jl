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
```jldoctest; setup=:(using CropPhenoFromDrones, StatsBase, DataFrames)
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
- DataFrame: A DataFrame with columns `id` (String) and `geometry` (ArchGDAL polygon objects) representing per-cell polygons; where the CRS of the raster is assigned to the returned DataFrame via GeoDataFrames.setcrs!.

# Details
- Each polygon corresponds to a rectangular cell formed by consecutive X and Y grid coordinates derived from dims(raster, Rasters.X).val and dims(raster, Rasters.Y).val
- Cell corners are ordered to close the polygon
- IDs are generated as "plot1", "plot2", ...
- ArchGDAL.createpolygon is used to construct geometries

# Notes
The function assumes a regular raster grid, presence of ArchGDAL and GeoDataFrames functionality, and that the geometry column is named `geometry` (Shapefile exports impose a 10-character column name limit).

# Examples
```jldoctest; setup=:(using CropPhenoFromDrones, StatsBase, DataFrames)
julia> raster = simulate_raster();

julia> df = simulate_shapes(raster);

julia> prod(size(raster.data) .- 1) == nrow(df)
true

julia> names(df) == ["id", "geometry"]
true

julia> typeof(df.id) == Vector{String}
true

julia> typeof(df.geometry) == Vector{ArchGDAL.IGeometry{ArchGDAL.wkbPolygon}}
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
            push!(coordinates, polygon)
        end
    end
    polygons = ArchGDAL.createpolygon.(coordinates)
    df = DataFrame(id = string.("plot", 1:length(polygons)), geometry = polygons)
    # Note: set geometry column only required if the column is not named "geometry" , also note that column names are restricted to 10 characters in the Shapefile format specs
    # GeoDataFrames.setgeometrycolumn!(df, :geom) 
    # # Set coordinate reference system
    GeoDataFrames.setcrs!(df, crs(raster))
    return df
end

# TODO: docstring and tests...
function simulate_layout(df::DataFrame; replications::Int64 = 2)::DataFrame
    # raster = simulate_raster(); df::DataFrame = simulate_shapes(raster); replications::Int64 = 2
    if ("id" ∉ names(df)) || ("geometry" ∉ names(df))
        throw(
            ErrorException(
                "The input Shapefile DataFrame is missing the `id` and/or `geometry` field/s!",
            ),
        )
    end
    row::Vector{Float64} = []
    column::Vector{Float64} = []
    for i = 1:nrow(df)
        # i = 1
        geom = ArchGDAL.getgeom.(df.geometry, 0)[i]
        p00 = ArchGDAL.getpoint(geom, 0)
        p11 = ArchGDAL.getpoint(geom, 2)
        centre = p00 .+ (p11 .- p00) ./ 2
        push!(row, centre[1])
        push!(column, centre[2])
    end
    n = Int64(ceil(nrow(df) / replications))
    df_layout = DataFrame(
        id = df.id,
        name = sample(string.("entry_", 1:n), nrow(df)),
        row = row,
        column = column,
        block = "blk_1",
    )
    return df_layout
end

# TODO: docstring and tests...
# channels, df_shapes, df_layout, fnames = simulate(overwrite=true)
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
    save::Bool = true,
    fname_prefix::String = "simulated",
    overwrite::Bool = false,
    seed::Int64 = 42,
)::Tuple{Dict{String,Raster},DataFrame,DataFrame,Union{Nothing,Vector{String}}}
    # lon_ini::Float64=25.0; lon_fin::Float64=30.0; lon_step::Float64=1.0; lat_ini::Float64=25.0; lat_fin::Float64=30.0; lat_step::Float64=1.0; EPSG_code::Int64=32754; n_time_points::Int64=1; μ::Float64 = 0.0; σ::Float64 = 1.0; seed::Int64 = 42; bands::Vector{String}=["red", "green", "blue", "nir"]; save::Bool = true; fname_prefix::String = "simulated"; overwrite::Bool = true; seed::Int64 = 42;
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
    end
    df_shapes = simulate_shapes(channels[bands[1]])
    df_layout = simulate_layout(df_shapes)
    # Save individual tiffs per band (GeRasters) and also the shapes (GeoVectors) and layouts (field layout information mapping the entry or genotype or cultivar names with the plot ids in the Shapefile)
    fnames::Union{Nothing,Vector{String}} = if save
        fnames = []
        for (channel, raster) in channels
            fname_tiff = write_raster(
                raster,
                path = "$fname_prefix-$channel.tiff",
                overwrite = overwrite,
            )
            push!(fnames, fname_tiff)
        end
        fname_shp =
            write_shapes(df_shapes, path = "$fname_prefix.shp", overwrite = overwrite)
        for suffix in [".shp", ".shx", ".prj", ".dbf"]
            push!(fnames, replace(fname_shp, ".shp" => suffix))
        end
        fname_tsv = write_layout(
            df_layout,
            path = "$fname_prefix-layout.tsv",
            overwrite = overwrite,
        )
        push!(fnames, fname_tsv)
    else
        nothing
    end
    # Output
    (channels, df_shapes, df_layout, fnames)
end
