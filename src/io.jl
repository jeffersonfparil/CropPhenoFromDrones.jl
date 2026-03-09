struct Data
    channels::Dict{String,Raster}
    df_shapes::DataFrame
    df_layout::DataFrame
    df_phenotypes::DataFrame
    fnames_channels::Vector{String}
    fnames_shapes::Vector{String}
    fname_layout::String
    fname_phenotypes::String
    function Data(;
        channels::Dict{String,Raster},
        df_shapes::DataFrame,
        df_layout::DataFrame,
        df_phenotypes::DataFrame,
        fnames_channels::Union{Nothing,Vector{String}}=nothing,
        fnames_shapes::Union{Nothing,Vector{String}}=nothing,
        fname_layout::Union{Nothing,String}=nothing,
        fname_phenotypes::Union{Nothing,String}=nothing,
    )::Data
        tmp_date = Dates.now()
        fnames_channels = if isnothing(fnames_channels)
            ["tmp-$tmp_date-$channel.tiff" for (channel, raster) in channels]
        else
            fnames_channels
        end
        fnames_shapes = if isnothing(fnames_shapes)
            ["tmp-$tmp_date.$suffix" for suffix in ["shp", "shx", "prj", "dbf"]]
        else
            fnames_shapes
        end
        fname_layout = if isnothing(fname_layout)
            "tmp-$tmp_date-layout.tsv"
        else
            fname_layout
        end
        fname_phenotypes = if isnothing(fname_phenotypes)
            "tmp-$tmp_date-phenotypes.tsv"
        else
            fname_phenotypes
        end
        new(channels, df_shapes, df_layout, df_phenotypes, fnames_channels, fnames_shapes, fname_layout, fname_phenotypes)
    end
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

function write_data(data::Data; overwrite::Bool = false)::Nothing
    # Save individual tiffs per band (GeRasters) and also the shapes (GeoVectors) and layouts (field layout information mapping the entry or genotype or cultivar names with the plot ids in the Shapefile)
    for (channel, raster) in data.channels
        fname_tiff = write_raster(
            raster,
            path = data.fnames_channels[.!isnothing.(match.(Regex(channel), data.fnames_channels))][1],
            overwrite = overwrite,
        )
    end
    fname_shp = write_shapes(
        data.df_shapes, 
        path = data.fnames_shapes[.!isnothing.(match.(Regex(".shp\$"), data.fnames_shapes))][1], 
        overwrite = overwrite
    )
    fname_tsv = write_layout(
        data.df_layout,
        path = data.fname_layout,
        overwrite = overwrite,
    )
    CSV.write(data.fname_phenotypes, data.df_phenotypes)
    nothing
end

##########################################################################################

function load_raster(path::String)::Raster
    Raster(path)
end

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
