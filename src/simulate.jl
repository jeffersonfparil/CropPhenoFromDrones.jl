lon_ini = 25.0
lon_fin = 30.0
lon_step = 1.0
lat_ini = 25.0
lat_fin = 30.0
lat_step = 1.0

lon, lat = Rasters.X(lon_ini:lon_step:lon_fin), Rasters.Y(lat_ini:lat_step:lat_fin)
ti = Ti([Dates.now()])
ras = Rasters.Raster(rand(lon, lat, ti))

coordinates::Vector{Vector{Tuple{Float64, Float64}}} = []
xs = collect(lon_ini:lon_step:lon_fin)
ys = collect(lat_ini:lat_step:lat_fin)
for i in 1:(length(xs)-1)
    for j in 1:(length(ys)-1)
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

df = DataFrame(
    geom=polygons,
    name=string.("plot", 1:length(polygons)),
)
GeoDataFrames.setgeometrycolumn!(df, :geom)  # set geometry column
GeoDataFrames.setcrs!(df, EPSG(4326))  # set coordinate reference system

GeoDataFrames.write("test.shp", df)
df_reloaded = GeoDataFrames.read("test.shp")
    

# TEST:

function parse_roi_geometries(;
    fname_shp::String,
    fname_layout::String,
)::Tuple{DataFrame,String}
    # fname_shp = joinpath(dir_tmp, "2023-10-23_STR-NUE-WUE-2023_plot.shp")
    # fname_layout = joinpath(dir_tmp, "2023-09-05_STR-NUE-WUE-plot_layout.txt")
    df_shp = GeoDataFrames.read(fname_shp)
    df_lyt = CSV.read(fname_layout, DataFrames.DataFrame)
    select!(df_lyt, [:id, :population_id])
    rename!(df_lyt, "population_id" => "name")
    df_lyt.name .= String.(df_lyt.name)
    S = leftjoin(df_shp, df_lyt, on=[:id], makeunique=true)
    disallowmissing!(S)
    fname_shp_updated = replace(fname_shp, r".shp$" => "-updated.shp")
    GeoDataFrames.write(fname_shp_updated, S)
    (S, fname_shp_updated)
end

# fname_shp, fname_layout, fnames_tiffs = let
#     dir = "/group/pasture/forages/Ryegrass/STR/NUE_WUE_merged_2022_2025/phenotypes/growth_rates/preprocessing_in_an_attempt_to_squeeze_in_pseudo_reps_per_flight/"
#     fname_shp = joinpath(dir, "2023-10-23_STR-NUE-WUE-2023_plot.shp")
#     fname_layout = joinpath(dir, "2023-09-05_STR-NUE-WUE-plot_layout.txt")
#     fnames = readdir(dir)
#     filter!(x -> !isnothing(match(r".tif$", x)), fnames)
#     fnames_tiffs = joinpath.(dir, fnames)
#     (fname_shp, fname_layout, fnames_tiffs)
# end

# df_rois, fname_shp_updated = parse_roi_geometries(fname_shp=fname_shp, fname_layout=fname_layout)

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
