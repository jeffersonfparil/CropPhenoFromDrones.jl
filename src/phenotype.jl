function remove_borders_per_raster!(raster::Raster; border_x_units::Int64=1, border_y_units::Int64=1)::Nothing
    # data = simulate_data(); raster = data.channels["red"]; border_x_units::Int64=2; border_y_units::Int64=3
    raster.data[1:border_x_units, :] .= missing
    raster.data[(end-border_x_units+1):end, :] .= missing
    raster.data[:, 1:border_y_units] .= missing
    raster.data[:, (end-border_y_units+1):end] .= missing
    nothing
end


function extract_rasters_per_plot(data::Data)::Dict{String,Dict{String,Raster}}
    # data = simulate_data()



    check_dimensions(data)
    rasters_per_plot::Dict{String,Dict{String,Raster}} = Dict()
    for (channel, raster) in data.channels
        # channel = string.(keys(data.channels))[1]; raster = data.channels[channel]
        rasters_per_plot[channel] = Dict()
        for (i, id) in enumerate(data.df_shapes.id)
            # i = 1; id = data.df_shapes.id[i]
            plot = Rasters.crop(raster, to=data.df_shapes.geometry[i])
            remove_borders_per_raster!(plot)
            rasters_per_plot[channel][id] = plot
        end
    end
    rasters_per_plot
end



function compute_indices(img; bands, index=:NDVI) # -> index_raster
    # TODO
end

function summarize_plot_features(plot_masks, feature_rasters) # -> DataFrame
    # TODO
end
