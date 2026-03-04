# CropPhenoFromDrones.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://CropPhenoFromDrones.github.io/CropPhenoFromDrones.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://CropPhenoFromDrones.github.io/CropPhenoFromDrones.jl/dev/)
[![Build Status](https://github.com/jeffersonfparil/CropPhenoFromDrones.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/jeffersonfparil/CropPhenoFromDrones.jl/actions)

## Summary

CropPhenoFromDrones.jl is a Julia package to support the end-to-end processing
of drone-derived remote sensing data for crop phenotyping.  The package is
designed to ingest, pre-process, and analyze multi-spectral, hyper-spectral,
and LiDAR point/cloud data together with geospatial raster and vector data
(GeoRaster and GeoVector). It provides utilities for radiometric and geometric
corrections, co-registration between modalities, vegetation index and spectral
feature extraction, canopy/terrain modelling from LiDAR, and linkage to field
observations and plots.

## Main goals

- Provide a modular, extensible toolchain for drone-based crop phenotyping.
- Support common remote-sensing data types: multispectral, hyperspectral,
    LiDAR (point clouds), and georeferenced rasters/vectors.
- Promote reproducible, documented workflows suitable for research and
    operational phenotyping pipelines.
- Interoperate cleanly with the Julia geospatial ecosystem (GeoData.jl,
    ArchGDAL.jl, GeoArrays.jl, GeoInterface.jl, etc.) and common scientific
    packages (Images.jl, DataFrames.jl).

## Key features

- Data ingestion layers for:
    - Multispectral and hyperspectral imagery (supporting common formats and
        metadata, with functions for reading spectral bands and associated
        wavelength tables).
    - LiDAR/point cloud loading (LAS/LAZ, and interoperable point-cloud
        structures).
    - GeoRaster/GeoTIFF and ancillary geospatial rasters.
    - GeoVector (shapefiles, GeoJSON) for field boundaries, plots, and ground
        control points.
- Radiometric & geometric preprocessing:
    - Dark/flat-field corrections, reflectance conversion (per-band calibration).
    - Atmospheric correction helpers (hooks for external tools/workflows).
    - Orthorectification and co-registration routines between imagery and LiDAR.
- Feature extraction:
    - Vegetation indices (NDVI, EVI, SAVI, custom index builder).
    - Spectral feature extraction for hyperspectral cubes (continuum removal,
        derivative spectra, band selection).
    - Canopy height model (CHM) generation from LiDAR and rasterization utilities.
- Plot/field-level aggregation:
    - Crop-plot masking, feature aggregation and time-series creation.
    - Tools for linking ground-truth measurements with remote-sensing-derived
        features.
- Utilities:
    - CRS-aware resampling and reprojection helpers.
    - Tile-based/streaming processing helpers to work with large datasets.
    - I/O helpers to export analysis-ready rasters, shapefiles, and CSV summary
        tables.

## Intended core API (conceptual)

- `simulate.jl`
    + simulate_raster()
    + simulate_vector()
- `io.jl`
    + load_raster(path::String) -> GeoRaster / GeoArray
    + load_hyperspec(path::String) -> HyperspectralCube (with wavelengths)
    + load_pointcloud(path::String) -> PointCloud (with XYZ, intensity, return info)
- `preprocess.jl`
    + calibrate_reflectance(img, calibration_metadata) -> calibrated_image
    + align_modalities(reference, target, method=:feature_based) -> transform
    + generate_chm(pointcloud; resolution=0.1, method=:max) -> CHM_raster
    + mask_plots(raster, plots_vector) -> Dict{PlotID, RasterMask}
- `phenotype.jl`
    + compute_indices(img; bands, index=:NDVI) -> index_raster
    + summarize_plot_features(plot_masks, feature_rasters) -> DataFrame
    
## Installation

```julia
using Pkg
Pkg.add("CropPhenoFromDrones")
```

## Dependencies

The package leverages existing Julia geospatial and scientific libraries where
possible. Typical dependencies (examples) include:
- GeoData.jl / GeoArrays.jl / ArchGDAL.jl for raster I/O and CRS handling
- LASIO.jl or PDAL.jl wrappers for LiDAR/point cloud operations
- Images.jl for image processing primitives
- DataFrames.jl for tabular outputs
- Proj4/Proj.jl for reprojection
- FileIO.jl for flexible I/O

## Data formats supported

- Rasters: GeoTIFF and other GDAL-supported raster formats.
- Hyperspectral stacks: ENVI, BSQ/BSQ-like and common cube formats (with
    associated wavelength metadata).
- Point clouds: LAS/LAZ (and other PDAL-read formats).
- Vectors: Shapefile, GeoJSON, and GDAL-supported vector formats.

## Usage example (conceptual)

1. Load imagery and LiDAR:
     img = load_raster("flight_mosaic.tif")
     pc  = load_pointcloud("flight_points.laz")

2. Calibrate and preprocess:
     img_ref = calibrate_reflectance(img, calib_meta)
     chm     = generate_chm(pc; resolution=0.1)

3. Align modalities and compute indices:
     transform = align_modalities(ref=img_ref, target=chm)
     ndvi = compute_indices(img_ref, index=:NDVI)

4. Mask plots and summarize:
     plots = load_vector("plots.geojson")
     masks = mask_plots(ndvi, plots)
     df = summarize_plot_features(masks, Dict(:NDVI => ndvi, :CHM => chm))

## Testing & Validation

- Unit tests for core numeric and I/O operations.
- Integration tests with small example datasets (multispectral, hyperspectral,
    LiDAR).
- Example notebooks or scripts that demonstrate common workflows and expected
    outputs.
