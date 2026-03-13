function simulate_raster(;
    lon_ini::Float64=142.00,
    lon_fin::Float64=143.00,
    lon_step::Float64=0.001,
    lat_ini::Float64=-35.00,
    lat_fin::Float64=-36.00,
    lat_step::Float64=0.001,
    EPSG_code::Int64=32754, # used in the Fan's 2023 GeoRaster data
    n_time_points::Int64=1,
    μ::Float64=0.0,
    σ::Float64=1.0,
    seed::Int64=42,
)::Raster
    # lon_ini::Float64=142.00; lon_fin::Float64=143.00; lon_step::Float64=0.001; lat_ini::Float64=-35.00; lat_fin::Float64=-36.00; lat_step::Float64=0.001; EPSG_code::Int64=32754; n_time_points::Int64=1; μ::Float64 = 0.0; σ::Float64 = 1.0; seed::Int64 = 42
    lon = Rasters.X(minimum([lon_ini, lon_fin]):lon_step:maximum([lon_ini, lon_fin]))
    lat = reverse(Rasters.Y(minimum([lat_ini, lat_fin]):lat_step:maximum([lat_ini, lat_fin]))) # we reversed lat because we opt to use the conventional north-up orientation
    N = Distributions.Normal(μ, σ)
    Random.seed!(seed)
    R::Array{Union{Missing,Float64}} = [;] # declare that the raster data can be missing or Float64
    raster = if n_time_points > 1
        ti = Ti([Dates.now()])
        R = rand(N, length(lon), length(lat), 1)
        Rasters.Raster(DimArray(R, (lon, lat, ti)), crs=EPSG(EPSG_code))
    else
        R = rand(N, length(lon), length(lat))
        Rasters.Raster(DimArray(R, (lon, lat)), crs=EPSG(EPSG_code))
    end
    # fig = CairoMakie.heatmap(raster; axis=(; aspect=GeoMakie.DataAspect())); CairoMakie.save("test.png", fig)
    return raster
end

function simulate_shapes(raster::Raster; rows::Int64=10, columns::Int64=10)::DataFrame
    # raster::Raster = simulate_raster(); rows::Int64=10; columns::Int64=10
    x_step = (dims(raster, Rasters.X)[end] - dims(raster, Rasters.X)[1]) / columns
    y_step = (dims(raster, Rasters.Y)[end] - dims(raster, Rasters.Y)[1]) / rows
    xs = collect(dims(raster, Rasters.X)[1]:x_step:dims(raster, Rasters.X)[end])
    ys = collect(dims(raster, Rasters.Y)[1]:y_step:dims(raster, Rasters.Y)[end])
    coordinates::Vector{Vector{Tuple{Float64,Float64}}} = []
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
    df_shapes = DataFrame(id=string.("plot", 1:length(polygons)), geometry=polygons)
    # Note: set geometry column only required if the column is not named "geometry" , also note that column names are restricted to 10 characters in the Shapefile format specs
    # GeoDataFrames.setgeometrycolumn!(df_shapes, :geom) 
    # Set coordinate reference system
    GeoDataFrames.setcrs!(df_shapes, crs(raster))
    # Sort columns alphabetical to be consistent with Shapefile specs
    select!(df_shapes, sort(propertynames(df_shapes)))
    return df_shapes
end

function simulate_phenotypes(
    df_shapes::DataFrame;
    max_replications::Int64=2,
    n_traits::Int64=1,
    i²::Vector{Float64}=[0.5],
    seed::Int64=42,
    channels::Union{Nothing,Dict{String,Raster}}=nothing,
)::DataFrame
    # channels = Dict("red" => simulate_raster(), "green" => simulate_raster(), "blue" => simulate_raster()); df_shapes = simulate_shapes(channels["red"]); max_replications::Int64=2; n_traits::Int64=1; i²::Vector{Float64}=[0.5]; seed::Int64=42
    Random.seed!(seed)
    # Simulate layout
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
    # Instantiate the phenotypes dataframe
    n = Int64(ceil(nrow(df_shapes) / max_replications))
    df_phenotypes = DataFrame(
        id=df_shapes.id,
        name=repeat(string.("entry_", 1:n), max_replications)[1:nrow(df_shapes)],
        row=row,
        column=column,
        block="block_1",
    )
    i² = repeat(i², outer=Int64(ceil(n_traits / length(i²))))[1:n_traits]
    if isnothing(channels) && isnothing(df_shapes)
        for i in 1:n_traits
            trait_name = "trait_$i"
            N = Distributions.Normal()
            df_phenotypes[!, trait_name] = rand(N, nrow(df_phenotypes))
        end
    elseif !isnothing(channels) && isnothing(df_shapes)
        throw(ErrorException("If you wish to use the simulated channels you also need to specify the shapes."))
    elseif isnothing(channels) && !isnothing(df_shapes)
        throw(ErrorException("If you wish to use the simulated shapes you also need to specify the channels."))
    else
        for i in 1:n_traits
            # i = 1
            df_phenotypes[!, "trait_$i"] .= 0.0
            zs = [
                [mean(skipmissing(Rasters.crop(raster, to=df_shapes.geometry[j]).data)) for j in 1:nrow(df_shapes)]
                for (channel, raster) in channels
            ]
            for z in zs
                # z = zs[1]
                N1 = Normal()
                N2 = Normal(0.0, 1 - i²[i])
                df_phenotypes[!, "trait_$i"] += ((100 * rand(N1)) .* z) + rand(N2, length(z))
            end
        end
    end
    return df_phenotypes
end

function simulate_data(;
    lon_ini::Float64=142.00,
    lon_fin::Float64=143.00,
    lon_step::Float64=0.001,
    lat_ini::Float64=-35.00,
    lat_fin::Float64=-36.00,
    lat_step::Float64=0.001,
    EPSG_code::Int64=32754, # used in the Fan's 2023 GeoRaster data
    n_time_points::Int64=1,
    μ::Float64=0.0,
    σ::Float64=1.0,
    bands::Vector{String}=["red", "green", "blue", "nir"],
    n_traits::Int64=1,
    max_replications::Int64=2,
    i²::Vector{Float64}=[0.5],
    overwrite::Bool=false,
    seed::Int64=42,
    save::Bool=true,
    verbose::Bool=true,
)::Data
    # lon_ini::Float64=142.00; lon_fin::Float64=143.00; lon_step::Float64=0.001; lat_ini::Float64=-35.00; lat_fin::Float64=-36.00; lat_step::Float64=0.001; EPSG_code::Int64=32754; n_time_points::Int64=1; μ::Float64 = 0.0; σ::Float64 = 1.0; seed::Int64 = 42; bands::Vector{String}=["red", "green", "blue", "nir"]; n_traits::Int64 = 1; save::Bool = true; fname_prefix::String = "simulated"; overwrite::Bool = true; seed::Int64 = 42; verbose::Bool=false
    Random.seed!(seed)
    pb = verbose ? ProgressMeter.Progress(length(bands), "Simulating the raster") : nothing
    channels::Dict{String,Raster} = Dict()
    for id in bands
        channels[id] = simulate_raster(
            lon_ini=lon_ini,
            lon_fin=lon_fin,
            lon_step=lon_step,
            lat_ini=lat_ini,
            lat_fin=lat_fin,
            lat_step=lat_step,
            EPSG_code=EPSG_code,
            n_time_points=n_time_points,
            μ=μ,
            σ=σ,
            seed=Int64(round(rand() * 10_000)),
        )
        verbose ? ProgressMeter.next!(pb) : nothing
    end
    verbose ? println("Simulating shapes (plot ROIs)...") : nothing
    df_shapes = simulate_shapes(channels[bands[1]])
    verbose ? println("Simulating phenotypes...") : nothing
    df_phenotypes = simulate_phenotypes(df_shapes, max_replications=max_replications, n_traits=n_traits, i²=i², channels=channels, seed=Int64(round(rand() * 10_000)))
    verbose ? ProgressMeter.finish!(pb) : nothing
    # Data
    data = Data(
        channels=channels,
        df_shapes=df_shapes,
        df_phenotypes=df_phenotypes,
    )
    # Save individual tiffs per band (GeRasters) and also the shapes (GeoVectors) and layouts (field layout information mapping the entry or genotype or cultivar names with the plot ids in the Shapefile)
    if save
        write_data(data, overwrite=overwrite)
    end
    # Output
    return data
end
