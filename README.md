# CropPhenoFromDrones

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://jeffersonfparil.github.io/CropPhenoFromDrones.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://jeffersonfparil.github.io/CropPhenoFromDrones.jl/dev/)
[![Build Status](https://github.com/jeffersonfparil/CropPhenoFromDrones.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/jeffersonfparil/CropPhenoFromDrones.jl/actions)

## Planned architecture

- `simulate.jl`
    + simulate_raster
    + simulate_shapes
    + simulate_layout
    + simulate
- `io.jl`
    + output_fname
    + write_raster
    + write_shapes
    + write_layout
    + load_raster
    + load_shapes_merge_layout
- `preprocess.jl`
    + calibrate_reflectance
    + align_modalities
    + generate_chm
    + mask_plots
- `phenotype.jl`
    + compute_indices
    + summarize_plot_features


## Dev stuff

```shell
julia +1.10 --threads=23,1 --project=. --load test/interactive_prelude.jl
time julia +1.10 --threads=24 --project=.  test/cli_tester.jl
```