module CropPhenoFromDrones

using Rasters

include("io.jl")
export load_raster, load_hyperspec, load_pointcloud

include("preprocess.jl")
calibrate_reflectance, align_modalities, generate_chm, mask_plots

include("phenotype.jl")
compute_indices, summarize_plot_features

end
