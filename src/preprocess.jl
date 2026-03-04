function calibrate_reflectance(img, calibration_metadata) # -> calibrated_image
    # TODO
end

function align_modalities(reference, target, method=:feature_based) # -> transform
    # TODO
end

function generate_chm(pointcloud; resolution=0.1, method=:max) # -> CHM_raster
    # TODO
end

function mask_plots(raster, plots_vector) # -> Dict{PlotID, RasterMask}
    # TODO
end
