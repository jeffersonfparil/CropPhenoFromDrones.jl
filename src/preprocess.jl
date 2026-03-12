function extract_traits_per_plot(data::Data)::DataFrame
    # data = simulate_data()
    check_dimensions(data)
    bool_traits_1 = [x ∉ ["id", "name", "row", "column", "block"] for x in names(data.df_phenotypes)]
    bool_traits_2 = [sum(isa.(data.df_phenotypes[!, x], Number)) > 0 for x in names(data.df_phenotypes)]
    bool_traits_3 = [isnothing(match(Regex("name_|row_|column_|block_|plot_index"), x)) for x in names(data.df_phenotypes)]
    idx_traits = findall(bool_traits_1 .&& bool_traits_2 .&& bool_traits_3)
    trait_names = if length(idx_traits) < 1
        throw(ErrorException("Missing trait names in data: $(names(data.df_phenotypes))"))
    else
        names(data.df_phenotypes)[idx_traits]
    end
    select(data.df_phenotypes, vcat(["id"], trait_names))
end

function remove_borders_per_raster!(raster::Raster; border_x_units::Int64=1, border_y_units::Int64=1)::Nothing
    # data = simulate_data(); raster = data.channels["red"]; border_x_units::Int64=2; border_y_units::Int64=3
    raster.data[1:border_x_units, :] .= missing
    raster.data[(end-border_x_units+1):end, :] .= missing
    raster.data[:, 1:border_y_units] .= missing
    raster.data[:, (end-border_y_units+1):end] .= missing
    nothing
end

function centroid_masking!(raster::Raster)::Nothing
    # data = simulate_data(lat_step=0.002); raster = data.channels["red"]
    n, p = size(raster.data)
    N = Distributions.Normal(sqrt(n / 2), 1)
    P = Distributions.Normal(sqrt(p / 2), 1)
    a1 = sort(rand(N, Int64(ceil(n / 2))))
    a2 = sort(rand(N, Int64(floor(n / 2))))
    b1 = sort(rand(P, Int64(ceil(p / 2))))'
    b2 = sort(rand(P, Int64(floor(p / 2))))'
    idx = vcat(
        hcat(
            a1 * b1 .<= (sqrt(n / 2) * sqrt(p / 2)),
            a1 * reverse(b2) .<= (sqrt(n / 2) * sqrt(p / 2)),
        ),
        hcat(
            a2 * reverse(b1) .> (sqrt(n / 2) * sqrt(p / 2)),
            a2 * b2 .> (sqrt(n / 2) * sqrt(p / 2)),
        )
    )
    raster.data[idx] .= missing
    nothing
end

function extract_rasters_per_plot(
    data::Data;
    border_x_units::Int64=0,
    border_y_units::Int64=0,
    centroid_sample::Bool=false
)::Dict{String,Dict{String,Raster}}
    # data = simulate_data(); border_x_units::Int64=0; border_y_units::Int64=0
    check_dimensions(data)
    rasters_per_plot::Dict{String,Dict{String,Raster}} = Dict()
    for (channel, raster) in data.channels
        # channel = string.(keys(data.channels))[1]; raster = data.channels[channel]
        rasters_per_plot[channel] = Dict()
        for (i, id) in enumerate(data.df_shapes.id)
            # i = 1; id = data.df_shapes.id[i]
            plot = Rasters.crop(raster, to=data.df_shapes.geometry[i])
            remove_borders_per_raster!(plot, border_x_units=border_x_units, border_y_units=border_y_units)
            centroid_sample ? centroid_masking!(plot) : nothing
            rasters_per_plot[channel][id] = plot
        end
    end
    rasters_per_plot
end

function ndvi(; nir, red)
    (nir - red) ./ (nir + red)
end

function ndgi(; nir, green)
    (nir - green) ./ (nir + green)
end

function ndbi(; nir, blue)
    (nir - blue) ./ (nir + blue)
end

function ndwi(; nir, green)
    (green - nir) ./ (green + nir)
end

function ndri(; red, green)
    (red - green) ./ (red + green)
end

function pndvi(; nir, red, green, blue)
    s = red + green + blue
    (nir - s) ./ (nir + s)
end

function extract_features(data::Data; cor_max::Float64=0.95)::DataFrame
    # Here we don't assume each plot has the same number of pixels
    # data = simulate_data(); cor_max::Float64=0.95
    df_features = DataFrame(id=data.df_phenotypes.id)
    ϕ::Vector{Union{Missing,Float64}} = repeat([missing], nrow(df_features))
    border_widths::Vector{Int64} = collect(0:5)
    for centroid_sample in [false, true]
        # centroid_sample = true
        for border_units in border_widths
            # border_units = border_widths[2]
            rasters = extract_rasters_per_plot(
                data,
                border_x_units=border_units,
                border_y_units=border_units,
                centroid_sample=centroid_sample
            )
            for (channel, shapes) in rasters
                # channel = string.(keys(rasters))[1]; shapes = rasters[channel]
                df_features[!, "$channel|$border_units|$centroid_sample|μ"] = deepcopy(ϕ)
                df_features[!, "$channel|$border_units|$centroid_sample|σ"] = deepcopy(ϕ)
                for (id, raster) in shapes
                    # id = string.(keys(shapes))[1]; raster = shapes[id]
                    # fig = heatmap(raster.data); save("test.png", fig)
                    df_features[df_features.id.==id, "$channel|$border_units|$centroid_sample|μ"] .= mean(skipmissing(raster))
                    df_features[df_features.id.==id, "$channel|$border_units|$centroid_sample|σ"] .= std(skipmissing(raster))
                end
            end
            # Vegetation indices
            nir = try
                df_features[!, "nir|$border_units|$centroid_sample|μ"]
            catch
                nothing
            end
            red = try
                df_features[!, "red|$border_units|$centroid_sample|μ"]
            catch
                nothing
            end
            green = try
                df_features[!, "green|$border_units|$centroid_sample|μ"]
            catch
                nothing
            end
            blue = try
                df_features[!, "blue|$border_units|$centroid_sample|μ"]
            catch
                nothing
            end
            if !isnothing(nir) && !isnothing(red)
                df_features[!, "ndvi|$border_units|$centroid_sample|μ"] = ndvi.(nir=nir, red=red)
            end
            if !isnothing(nir) && !isnothing(green)
                df_features[!, "ndgi|$border_units|$centroid_sample|μ"] = ndgi.(nir=nir, green=green)
            end
            if !isnothing(nir) && !isnothing(blue)
                df_features[!, "ndbi|$border_units|$centroid_sample|μ"] = ndbi.(nir=nir, blue=blue)
            end
            if !isnothing(nir) && !isnothing(green)
                df_features[!, "ndwi|$border_units|$centroid_sample|μ"] = ndwi.(nir=nir, green=green)
            end
            if !isnothing(red) && !isnothing(green)
                df_features[!, "ndri|$border_units|$centroid_sample|μ"] = ndri.(red=red, green=green)
            end
            if !isnothing(nir) && !isnothing(red) && !isnothing(green) && !isnothing(blue)
                df_features[!, "pndvi|$border_units|$centroid_sample|μ"] = pndvi.(nir=nir, red=red, green=green, blue=blue)
            end
        end
    end
    # Remove correlated features
    i = 2
    j = i + 1
    while i <= (ncol(df_features) - 1)
        while j <= ncol(df_features)
            if abs(cor(df_features[:, i], df_features[:, j])) > cor_max
                select!(df_features, Not(names(df_features)[j]))
            end
            j += 1
        end
        i += 1
        j = i + 1
    end
    if ncol(df_features) < 3
        throw(ErrorException("Homogenous feature set: we have less than 2 features extracted: $(names(df_features))"))
    end
    # Output
    df_features
end

function extract_XY(data::Data; cor_max::Float64=0.95)::Tuple{DataFrame,DataFrame}
    # data = simulate_data(); cor_max::Float64=0.95
    check_dimensions(data)
    df_traits = extract_traits_per_plot(data)
    trait_names = names(select(df_traits, Not(:id)))
    df_features = extract_features(data, cor_max=cor_max)
    df_merged = leftjoin(df_traits, df_features, on=:id)
    if nrow(df_merged) < 3
        throw(ErrorException("We have less than 3 data-points"))
    end
    (
        select(df_merged, vcat("id", trait_names)),
        select(df_merged, Not(trait_names)),
    )
end
