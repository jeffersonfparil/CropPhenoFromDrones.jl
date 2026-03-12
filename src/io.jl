function output_fname(;
    path::String="",
    default_prefix::String="simulated",
    extension_name::String="tif",
    overwrite::Bool=false,
)::String
    # path::String=""; default_prefix::String="simulated"; extension_name::String="tif"; overwrite::Bool=false; verbose::Bool=false
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

mutable struct Data
    channels::Dict{String,Raster}
    df_shapes::DataFrame
    df_phenotypes::DataFrame
    fnames_channels::Vector{String}
    fnames_shapes::Vector{String}
    fname_phenotypes::String
    function Data(;
        channels::Dict{String,Raster},
        df_shapes::DataFrame,
        df_phenotypes::DataFrame,
        fnames_channels::Union{Nothing,Vector{String}}=nothing,
        fnames_shapes::Union{Nothing,Vector{String}}=nothing,
        fname_phenotypes::Union{Nothing,String}=nothing,
    )::Data
        fnames_channels = if isnothing(fnames_channels)
            [output_fname(default_prefix="simulated-$channel", extension_name="tif") for (channel, _raster) in channels]
        else
            if length(fnames_channels) != length(channels)
                throw(ErrorException("Incompatible number of channels (n=$(length(channels))) and channel filenames (n=$(length(fnames_channels)))"))
            end
            fnames_channels
        end
        fnames_shapes = if isnothing(fnames_shapes)
            [output_fname(default_prefix="simulated", extension_name=extension_name) for extension_name in ["shp", "shx", "prj", "dbf"]]
        else
            if length(fnames_shapes) != 4
                throw(ErrorException("We expect 4 filenames for `fnames_shapes` with the following expension names: [\".shp\", \".shx\", \".prj\", \".dbf\"]"))
            end
            fnames_shapes
        end
        fname_phenotypes = if isnothing(fname_phenotypes)
            output_fname(default_prefix="simulated-phenotypes", extension_name="tsv")
        else
            fname_phenotypes
        end
        new(channels, df_shapes, df_phenotypes, fnames_channels, fnames_shapes, fname_phenotypes)
    end
end

function write_raster(raster::Raster; path::String, overwrite::Bool=false)::String
    # raster = simulate_raster(); path = "simulated-red.tif"; overwrite = true;
    fname_tif = output_fname(path=path, overwrite=overwrite)
    Rasters.write(fname_tif, raster, force=overwrite)
    fname_tif
end

function write_shapes(df_shapes::DataFrame; path::String, overwrite::Bool=false)::Vector{String}
    # df_shapes = simulate_shapes(simulate_raster()); path = "simulated.shp"; overwrite = true;
    fname_shp = output_fname(path=path, overwrite=overwrite)
    GeoDataFrames.write(fname_shp, df_shapes)
    # Gather names of all the resulting shape files, i.e. ".shp", ".shx", ".prj", and ".dbf"
    dir = dirname(fname_shp) == "" ? "." : dirname(fname_shp)
    fnames_in_dir = readdir(dir)
    prefix = replace(basename(fname_shp), ".shp" => "")
    idx_shapes = []
    for extension_name in ["shp", "shx", "prj", "dbf"]
        idx = findall(fnames_in_dir .== "$prefix.$extension_name")
        if length(idx) == 0
            throw(ErrorException("Cannot find shape file: $prefix.$extension_name"))
        end
        push!(idx_shapes, idx[1])
    end
    fnames_in_dir[idx_shapes]
end

function write_phenotypes(df_phenotypes::DataFrame; path::String, overwrite::Bool=false)::String
    # df_phenotypes = simulate_phenotypes(simulate_shapes(simulate_raster())); path = "simulated-phenotypes.tsv"; overwrite = true;
    fname_tsv = output_fname(path=path, overwrite=overwrite)
    CSV.write(fname_tsv, df_phenotypes, delim="\t")
    fname_tsv
end

function write_data(data::Data; overwrite::Bool=false)::Nothing
    # Save individual tifs per band (GeRasters) and also the shapes (GeoVectors) and layouts (field layout information mapping the entry or genotype or cultivar names with the plot ids in the Shapefile)
    # Note that we update the filenames if overwrite==false
    for (channel, raster) in data.channels
        # channel = string.(keys(data.channels))[1]; raster = data.channels[channel]
        idx_fname = findfirst(.!isnothing.(match.(Regex(channel), data.fnames_channels)))
        data.fnames_channels[idx_fname] = write_raster(
            raster,
            path=data.fnames_channels[idx_fname],
            overwrite=overwrite,
        )
    end
    data.fnames_shapes = write_shapes(
        data.df_shapes,
        path=data.fnames_shapes[findfirst(.!isnothing.(match.(Regex(".shp\$"), data.fnames_shapes)))],
        overwrite=overwrite
    )
    data.fname_phenotypes = write_phenotypes(
        data.df_phenotypes,
        path=data.fname_phenotypes,
        overwrite=overwrite,
    )
    nothing
end

##########################################################################################

function load_raster(path::String)::Raster
    Raster(path)
end

function load_shapes_phenotypes(
    fname_shapes::String;
    fname_phenotypes::Union{Nothing,String}=nothing,
    id::String="id",
    name::String="name",
    remove_rows_with_missing::Bool=true,
)::DataFrame
    # channels::Dict{String,Raster} = Dict("red" => simulate_raster(), "green" => simulate_raster(), "blue" => simulate_raster())
    # df_shapes = simulate_shapes(channels["red"])
    # df_phenotypes = simulate_phenotypes(df_shapes, channels=channels)
    # fname_shapes::String = write_shapes(df_shapes, path="simulated.shp", overwrite=true)[1]
    # fname_phenotypes::Union{Nothing,String} = write_phenotypes(df_phenotypes, path="simulated-phenotypes.tsv", overwrite=true)
    # id::String = "id"
    # name::Union{Nothing,String} = "name"
    # remove_rows_with_missing::Bool = true
    #############################################
    df_shapes = GeoDataFrames.read(fname_shapes)
    if id ∉ names(df_shapes)
        throw(ErrorException("The id column (\"$id\") is absent in \"$fname_shapes\"."))
    end
    df_phenotypes = if isnothing(fname_phenotypes)
        nothing
    else
        df_phenotypes = CSV.read(fname_phenotypes, DataFrames.DataFrame)
        if (id ∉ names(df_phenotypes)) || (name ∉ names(df_phenotypes))
            throw(
                ErrorException(
                    "Columns \"$id\" and/or \"$name\" are not found in \"$fname_phenotypes\".",
                ),
            )
        end
        # Set all AbstractString into simply String for compatibility with Shapefile specs
        for f in names(df_phenotypes)
            # f = names(df_phenotypes)[1]
            bool = false
            for x in df_phenotypes[!, f]
                if x isa AbstractString
                    bool = true
                    break
                end
            end
            if bool
                df_phenotypes[!, f] = String.(df_phenotypes[!, f])
            end
        end
        df_phenotypes
    end
    # Output
    if isnothing(df_phenotypes)
        return df_shapes
    else
        df_merged = leftjoin(df_shapes, df_phenotypes, on=[:id], makeunique=true)
        df_merged = if remove_rows_with_missing
            idx = findall(sum(Matrix(ismissing.(df_merged)), dims=2)[:, 1] .== 0)
            disallowmissing(df_merged[idx, :])
        else
            df_merged
        end
        # Sort columns alphabetical to be consistent with Shapefile specs
        select!(df_merged, sort(propertynames(df_merged)))
        return df_merged
    end
end

function check_dimensions(data::Data)::Nothing
    # data = simulate_data();
    # Check raster dimensions
    d = dims(first(data.channels)[end])
    for (channel, raster) in data.channels
        if d != dims(raster)
            throw(ErrorException("Differing dimensions between raster images (see \"$channel\")."))
        end
    end
    x_limits = dims(first(data.channels)[end], Rasters.X)[[1, end]]
    y_limits = dims(first(data.channels)[end], Rasters.Y)[[1, end]]
    whole_canvas = ArchGDAL.createpolygon([
        (x_limits[1], y_limits[1]),
        (x_limits[1], y_limits[2]),
        (x_limits[2], y_limits[2]),
        (x_limits[2], y_limits[1]),
        (x_limits[1], y_limits[1]),
    ])
    # Check if the geometries are within bounds of the rasters
    for roi in data.df_shapes.geometry
        # roi = data.df_shapes.geometry[1]
        if !ArchGDAL.within(roi, whole_canvas)
            throw(ErrorException("At least one plot is beyond the area defined in the raster file/s (see $roi)."))
        end
    end
    # Check if the id columns are present in df_phenotypes
    if "id" ∉ names(data.df_shapes)
        throw(ErrorException("Missing `id` column in df_shapes"))
    end
    if "id" ∉ names(data.df_phenotypes)
        throw(ErrorException("Missing `id` column in df_phenotypes"))
    end
    nothing
end

function load_data(;
    fnames_channels::Vector{String},
    fname_shapes::String,
    fname_phenotypes::String,
    id::String="id",
    name::String="name",
    remove_rows_with_missing::Bool=true,
    verbose::Bool=true,
)::Data
    # data = simulate_data(); fnames_channels = data.fnames_channels; fname_shapes = data.fnames_shapes[1]; fname_phenotypes = data.fname_phenotypes; id::String="id"; name::String="name"; remove_rows_with_missing::Bool=true; verbose::Bool=true
    channels::Dict{String,Raster} = Dict()
    splits = [vcat(split.(x, "-")...) for x in split.(basename.(fnames_channels), ".")]
    bool = [.!isnothing.(match.(Regex("red|green|blue"), y)) for y in splits]
    idx_key = findfirst(sum(hcat(bool...), dims=2)[:, 1] .> 0)
    if verbose
        pb = ProgressMeter.Progress(length(fnames_channels), "Loading rasters")
    end
    for (i, f) in enumerate(fnames_channels)
        # i = 2; f = fnames_channels[i]
        key = splits[i][idx_key]
        channels[key] = load_raster(f)
        if verbose
            ProgressMeter.next!(pb)
        end
    end
    if verbose
        ProgressMeter.finish!(pb)
    end
    df = load_shapes_phenotypes(
        fname_shapes,
        fname_phenotypes=fname_phenotypes,
        id=id,
        name=name,
        remove_rows_with_missing=remove_rows_with_missing
    )
    # Output
    data = Data(
        channels=channels,
        df_shapes=select(df, [id, "geometry"]),
        df_phenotypes=select(df, Not(:geometry)),
        fnames_channels=fnames_channels,
        fnames_shapes=[replace(fname_shapes, ".shp" => suffix) for suffix in [".shp", ".shx", ".prj", ".dbf"]],
        fname_phenotypes=fname_phenotypes,
    )
    check_dimensions(data)
    data
end