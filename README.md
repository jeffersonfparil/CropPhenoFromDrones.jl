# CropPhenoFromDrones.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://jeffersonfparil.github.io/CropPhenoFromDrones.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://jeffersonfparil.github.io/CropPhenoFromDrones.jl/dev/)
[![Build Status](https://github.com/jeffersonfparil/CropPhenoFromDrones.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/jeffersonfparil/CropPhenoFromDrones.jl/actions)

## Planned architecture

- `simulate.jl`
    + simulate_raster()
    + simulate_vector()
- `io.jl`
    + load_raster()
    + load_hyperspec()
    + load_pointcloud()
- `preprocess.jl`
    + calibrate_reflectance()
    + align_modalities()
    + generate_chm()
    + mask_plots()
- `phenotype.jl`
    + compute_indices()
    + summarize_plot_features()

