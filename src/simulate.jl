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

function simulate_phenotypes(df_layout::DataFrame; n_traits::Int64=1)::DataFrame
    # df_layout = simulate_raster() |> x -> simulate_shapes(x) |> x -> simulate_layout(x); n_traits::Int64=1
    df_phenotypes = deepcopy(df_layout)
    for i in 1:n_traits
        trait_name = "trait_$i"
        df_phenotypes[!, trait_name] = randn(nrow(df_layout))
    end
    return df_phenotypes
end

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
)::Data
    # lon_ini::Float64=25.0; lon_fin::Float64=30.0; lon_step::Float64=1.0; lat_ini::Float64=25.0; lat_fin::Float64=30.0; lat_step::Float64=1.0; EPSG_code::Int64=32754; n_time_points::Int64=1; μ::Float64 = 0.0; σ::Float64 = 1.0; seed::Int64 = 42; bands::Vector{String}=["red", "green", "blue", "nir"]; n_traits::Int64 = 1; save::Bool = true; fname_prefix::String = "simulated"; overwrite::Bool = true; seed::Int64 = 42; verbose::Bool=false
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
    # Data
    data = Data(
        channels=channels,
        df_shapes=df_shapes,
        df_layout=df_layout,
        df_phenotypes=df_phenotypes,
    )
    # Save individual tiffs per band (GeRasters) and also the shapes (GeoVectors) and layouts (field layout information mapping the entry or genotype or cultivar names with the plot ids in the Shapefile)
    if save
        write_data(data, overwrite = overwrite)
    end
    # Output
    return data
end
