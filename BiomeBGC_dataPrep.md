---
title: "BiomeBGC_dataPrep"
author: 
  - Dominique Caron
  - Céline Boisvenue
date: "February 2026"
output:
  html_document:
    keep_md: yes
bibliography: citation.bib
editor_options:
  chunk_output_type: console
---



# Overview

Biome-BGC is an ecophysiological model that simulates carbon, nitrogen, and water cycling in
forest ecosystems. Before it can be run, Biome-BGC needs a set of site-level inputs (e.g.,
meteorology, soil properties, species parameters) assembled into the specific `.ini` control
files that the model reads. `BiomeBGC_dataPrep` retrieves and prepares those inputs for one or
more sites (or polygons) and writes the `.ini` files needed to run Biome-BGC version 4.2 through
the module `BiomeBGC_core`.

Biome-BGC simulations happen in two stages, and this module prepares inputs for both:

- A **spin-up** run, which repeats historical climate conditions over many years until the
  simulated carbon and nitrogen pools reach a steady state. This gives the main simulation a
  realistic starting point instead of an arbitrary one.
- The **main** simulation run, which uses the spin-up's final state as its starting point and
  runs over the user's simulation period.

The user only needs to supply a study area (as one or more polygons, or points representing
site locations); all other inputs have Canada-wide defaults that the module will download and
process automatically if not supplied. Users can override any default by supplying their own
data for that input (see [Input data](#input-data) below).

# Set up

A minimal simulation needs a `studyArea`, plus a `rasterToMatch` if `studyArea` is a polygon
(points do not require one, since each point is treated as its own site). All other inputs fall
back to defaults described below.


``` r
library(SpaDES.core)

mySim <- simInit(
  times = list(start = 2011, end = 2011),
  params = list(
    BiomeBGC_dataPrep = list(
      co2scenario = "RCP45",
      metSpinupYears = 40
    )
  ),
  modules = "BiomeBGC_dataPrep",
  objects = list(
    studyArea = studyArea, # a SpatVector of polygons or points
    rasterToMatch = rasterToMatch # required only if studyArea is a polygon
  ),
  paths = list(
    modulePath = "..",
    inputPath = "inputs",
    outputPath = "outputs"
  )
)

mySimOut <- spades(mySim)
```

# Parameters

The module's parameters fall into a few groups:

- **Spin-up controls** — `maxSpinupYears` (an upper limit on the number of simulated spin-up
  years) and `metSpinupYears` (how many years of historical meteorological data are recycled
  during spin-up).
- **Climate-change scenario** — `climModel` (which climate model to use: `"RCM4"`, `"GCM4"`, or
  `"Hadley"`), `co2scenario` (`"RCP45"` or `"RCP85"`, i.e. a lower- or higher-emissions future
  pathway), and `climateChangeOptions` (manual offsets/multipliers applied to future
  temperature, precipitation, humidity, and solar radiation, for sensitivity analyses).
- **Initial model state** — `carbonState`, `nitrogenState`, and `waterState` set the starting
  carbon, nitrogen, and water pools for the spin-up; `siteConstants` holds fixed site
  characteristics (soil depth, soil texture, elevation, latitude, albedo, N deposition, N
  fixation) that are otherwise filled in from the input data described below;
  `NDepositionLevel` controls whether atmospheric nitrogen deposition is held constant or
  allowed to vary with the CO2 scenario.
- **Output control** — `outputVariables` (which daily Biome-BGC output variables to request)
  and `savePixelGroupMap` (whether to keep the raster of pixel groups as a saved output).
- **Standard SpaDES parameters** — the `.plots`, `.plotInitialTime`, `.plotInterval`,
  `.saveInitialTime`, `.saveInterval`, `.studyAreaName`, `.seed`, and `.useCache` parameters
  follow the usual SpaDES conventions for controlling plotting, saving, and caching, shared
  across all SpaDES modules.


|paramName            |paramClass |default      |min |max |paramDesc                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
|:--------------------|:----------|:------------|:---|:---|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|carbonState          |numeric    |0.001, 0.... |NA  |NA  |11-number vector for initial carbon conditions: 1: peak leaf carbon to be attained during the first simulation year (kgC/m2) 2: peak stem carbon to be attained during the first year (kgC/m2) 3: initial coarse woody debris carbon (dead trees, standing or fallen) (kgC/m2) 4: initial litter carbon, labile pool (kgC/m2) 5: initial litter carbon, unshielded cellulose pool (kgC/m2) 6: initial litter carbon, shielded cellulose pool (kgC/m2) 7: initial litter carbon, lignin pool (kgC/m2) 8: soil carbon, fast pool (kgC/m2) 9: soil carbon, medium pool (kgC/m2) 10: soil carbon, slow pool (kgC/m2) 11: soil carbon, slowest pool (kgC/m2) |
|climModel            |character  |RCM4         |NA  |NA  |A climatic model to extract meteorological data. Either 'RCM4', 'GCM4', or 'Hadley'.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
|climateChangeOptions |numeric    |0, 0, 1,.... |NA  |NA  |Entries in the CLIMATE_CHANGE section of the ini file. The entries are: offset for Tmax, offset for Tmin multiplier for prcp, multiplier for vpd, and muliplier for srad.                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
|co2scenario          |character  |RCP45        |NA  |NA  |An representative concentration pathway for the co2 concentration trajectories and meteorological data. Either 'RCP45' or 'RCP85'.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
|maxSpinupYears       |integer    |6000         |NA  |NA  |The maximum number of simulation for a spinup run.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
|metSpinupYears       |numeric    |40           |NA  |NA  |The number of years used for the spinup, i.e. the length of the historical met record the spinup cycles through to reach equilibrium. This controls only the spinup period (ending the year before start(sim)); it no longer extends the main simulation's date range, which always spans start(sim) to end(sim).                                                                                                                                                                                                                                                                                                                                       |
|NDepositionLevel     |numeric    |1, NA, NA    |NA  |NA  |A 3-number vector: 1) Keep nitrogen deposition level constant (0) or vary according to the time trajectory of CO2 mole fractions (1). 2) The reference year for N deposition (only used when N-deposition varies). 3) Industrial N deposition value.                                                                                                                                                                                                                                                                                                                                                                                                    |
|nitrogenState        |numeric    |0, 0         |NA  |NA  |2-number vector for initial nitrogen conditions: 1: litter nitrogen associated with labile litter carbon pool (kgN/m2) 2: soil mineral nitrogen pool (kgN/m2)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
|outputVariables      |numeric    |0, 3, 54.... |NA  |NA  |The indices of the daily output variable(s) requested. There are >500 possible variables and are listed here: https://raw.githubusercontent.com/PredictiveEcology/BiomeBGCR/refs/heads/development/src/Biome-BGC/src/bgclib/output_map_init.c. The units of each variable are found here: https://raw.githubusercontent.com/PredictiveEcology/BiomeBGCR/refs/heads/development/src/Biome-BGC/src/include/bgc_struct.h.                                                                                                                                                                                                                                  |
|siteConstants        |numeric    |NA, NA, .... |NA  |NA  |A vector with site information: 1: effective soil depth 2: sand percentage 3: silt percentage 4: clay percentage 5: site elevation in meters 6: site latitude in decimal degrees 7: site shortwave albedo 8: annual rate of atmospheric nitrogen deposition 9: annual rate of symbiotic+asymbiotic nitrogen fixation The non-na constants will be retrieved in various sources.                                                                                                                                                                                                                                                                         |
|savePixelGroupMap    |logical    |FALSE        |NA  |NA  |If TRUE, the objects pixelGroupMap will be saved.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
|waterState           |vector     |NA, 0.5      |NA  |NA  |2-number vector for initial water conditions: 1: initial snowpack water content (kg/m2) 2: intial soil water content as a proportion of saturation (DIM) If set to NA, the initial snowpack water content will be retrieved by an external source.                                                                                                                                                                                                                                                                                                                                                                                                      |
|.plots               |character  |screen       |NA  |NA  |Used by Plots function, which can be optionally used here                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
|.plotInitialTime     |numeric    |0            |NA  |NA  |Describes the simulation time at which the first plot event should occur.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
|.plotInterval        |numeric    |NA           |NA  |NA  |Describes the simulation time interval between plot events.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
|.saveInitialTime     |numeric    |NA           |NA  |NA  |Describes the simulation time at which the first save event should occur.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
|.saveInterval        |numeric    |NA           |NA  |NA  |This describes the simulation time interval between save events.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
|.studyAreaName       |character  |NA           |NA  |NA  |Human-readable name for the study area used - e.g., a hash of the studyarea obtained using `reproducible::studyAreaName()`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
|.seed                |list       |             |NA  |NA  |Named list of seeds to use for each event (names).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
|.useCache            |logical    |FALSE        |NA  |NA  |Should caching of events or module be used?                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |

# Events

The module has two event types.

## Init

The `init` event does the main work of the module, in three steps:

1. **`preparePixelGroups`** groups pixels of the study area into "pixel groups" — sets of
   pixels that share the same climate polygon, dominant species, soil properties, and
   elevation, and so can be simulated with a single Biome-BGC run. This keeps the number of
   simulations manageable for large or spatially heterogeneous study areas. The grouping is
   stored in `pixelGroupMap` and summarized in `pixelGroupParameters`.
2. **`prepareSpinupIni`** writes one spin-up `.ini` file per pixel group (and per
   scenario, where relevant), including the recycled historical meteorology, initial carbon/
   nitrogen/water state, and the requested length of the spin-up.
3. **`prepareIni`** writes the corresponding main-run `.ini` files, carrying over the
   spin-up's restart state and substituting in the main simulation's meteorological data,
   simulation period, and CO2 concentration.

## Plotting

If plotting is enabled (via the standard `.plots`/`.plotInitialTime`/`.plotInterval`
parameters), a `plot` event produces two figures, saved as PNG files under
`outputPath(sim)/BiomeBGC_figures/`:

- `climatePlot` — a time series of annual temperature and precipitation for each climate
  polygon in the study area.
- `climatePolygonMap` — a map of the climate polygons, colour-coded by polygon ID, so the user
  can see how the climate data were spatially partitioned.

## Saving

No additional objects are saved by default beyond what is controlled by the standard SpaDES
`.saveInitialTime`/`.saveInterval` parameters. If `savePixelGroupMap = TRUE`, the
`pixelGroupMap` raster is kept as a saved output rather than being discarded after use.

# Data dependencies

## Input data

Input data are the parameters driving Biome-BGC. The default input data are from various
sources, scales, and precision levels. We calibrated default ecophysiological constants for
Canadian tree species by aggregating data from @white_parameterization_2000,
@hessl_ecophysiological_2004, and the TRY plant trait database [@kattge_try_2020].
Meteorological data are retrieved through the BioSIM package [@fortin_web_2022,
@fortin_package_2022]. Site-level parameters are extracted from the following sources:

- Dominant species: NTEMS dominant species layers for the 1st year of the simulation
  [@hermosilla_characterizing_2024].
- Elevation: AWS Open Data Terrain Tiles extracted with the `elevatr` package
  [@hollister_elevatr_2025].
- N deposition: Extracted from the ADAGIO project [@robichaud_data_2025, @robichaud_data_2026].
- N fixation rate: Extracted from @reis_ely_global_2025.
- Snow pack water content: Canada monthly snow water equivalent (SWE) for January
  [@mudryk_characterization_2015].
- Soil depth: The maximum soil depth layer of NACP MsTMIP: Unified North American Soil Map
  [@liu_north_2014].
- Soil texture (sand/silt/clay percentages): Soil Landscape Grids of Canada
  [@geng_100_2025].

The only input the user must supply is `studyArea`, one or more polygons or points defining
the area(s) or site(s) to simulate. All other inputs below have Canada-wide defaults that are
downloaded and processed automatically if not supplied:

- `climatePolygons` — polygons of climate zones in which Biome-BGC can be assumed to see
  homogeneous weather (default: Canadian ecodistricts).
- `CO2concentration` — a table of atmospheric CO2 concentration (ppm) by year, consistent with
  the chosen `co2scenario`.
- `ecophysiologicalConstants` — species-specific ecophysiological constants required by
  Biome-BGC.
- `rasterToMatch` — a template raster defining the extent, resolution, and projection to use;
  required if `studyArea` is a polygon (rather than points).
- `soilTextures` — the sand/silt/clay percentage layers (see above).
- `sppEquiv` — a species-equivalency table linking the dominant species map to the
  ecophysiological constants table.


|objectName                |objectClass |desc                                                                                                                                                                                                                                                                                               |sourceURL                                                                                    |
|:-------------------------|:-----------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:--------------------------------------------------------------------------------------------|
|climatePolygons           |SpatVector  |Polygons of homogeneous climate. By default, ecodistricts are used.                                                                                                                                                                                                                                |NA                                                                                           |
|CO2concentration          |data.frame  |CO2 concentration for each year.                                                                                                                                                                                                                                                                   |NA                                                                                           |
|dominantSpecies           |SpatRaster  |A raster with the leading tree species (speciesId). Use to determine the ecophysiological constants. By default, the NTEMS dominant tree species layer for the starting year is used.                                                                                                              |NA                                                                                           |
|ecophysiologicalConstants |data.frame  |Ecophysiological constants. Columns are speciesId, species, PFT, and the ecological constants (see template). By default, ecophysiologicalConstants are extracted from White et al., 2000, Hessl et al., 2004, and TRY.                                                                            |NA                                                                                           |
|elevation                 |SpatRaster  |An elevation (m) raster. By default, the raster will be extracted from AWS Terrain Tiles with the elevatr package.                                                                                                                                                                                 |https://registry.opendata.aws/terrain-tiles/                                                 |
|meteorologicalData        |list        |List of data.frames with the meteorological data for each climate polygons. The units are `deg C` for Tmax, Tmin, and Tday, `cm` for prcp, `Pa` for VPD, `W/m^2` for srad, and `s` for daylen.                                                                                                     |NA                                                                                           |
|Ndeposition               |SpatRaster  |Raster(s) of total atmospheric N deposition (kgN/m2/yr). If N deposition is variable two layers need to be provided, one for N deposition at the start, of the simulation and a second for N deposition at another timestep. The layer name of the second raster needs to be the year of the data. |https://doi.org/10.1016/j.atmosenv.2025.121074                                               |
|NfixationRates            |SpatRaster  |Raster of annual rate of symbiotic + asymbiotic nitrogen fixation (kgN/m2/yr).                                                                                                                                                                                                                     |https://www.sciencebase.gov/catalog/item/66a97480d34e07a119db3a37                            |
|rasterToMatch             |SpatRaster  |A raster defining the extent, resolution, projection of the study area. The user needs to provide the rasterToMatch if the studyArea is a polygon.                                                                                                                                                 |NA                                                                                           |
|snowpackWaterContent      |SpatRaster  |Initial snowpack water content (kg/m2).                                                                                                                                                                                                                                                            |https://climate-scenarios.canada.ca/?page=blended-snow-data                                  |
|soilDepth                 |SpatRaster  |A raster of effective soil depth (rooting zone depth) in m.                                                                                                                                                                                                                                        |https://www.earthdata.nasa.gov/data/catalog/ornl-cloud-nacp-mstmip-unified-na-soilmap-1242-1 |
|soilTextures              |SpatRaster  |A raster stack with layers representing the % of 'Sand', 'Silt', and 'Clay'. The across-layers sum needs to equal to 100 for each pixels.                                                                                                                                                          |https://sis.agr.gc.ca/cansis/nsdb/psm/index.html                                             |
|sppEquiv                  |data.frame  |A data frame to link the leading species map to ecophysiological constants. The columns are speciesId, species, genus, functional plant type.                                                                                                                                                      |NA                                                                                           |
|studyArea                 |SpatVector  |Polygons to use as the study area. Must be supplied by the user. One polygon per study site.                                                                                                                                                                                                       |NA                                                                                           |

## Output data

The module's main outputs are the Biome-BGC `.ini` control files, grouped by pixel group:

- `bbgcSpinup.ini` — a named list of parsed spin-up `.ini` objects (as returned by
  `BiomeBGCR::iniRead()`), one per pixel group/scenario, named by pixel group ID.
- `bbgc.ini` — a named list of parsed main-run `.ini` objects (same structure), which carry
  over the spin-up's ending state.

These parsed `.ini` objects are passed on to `BiomeBGC_core`, which writes them to disk (via
`BiomeBGCR::iniWrite()`) and runs Biome-BGC itself. The module also returns the spatial units
used to generate those files:

- `pixelGroupMap` — a raster showing which pixel group each pixel belongs to (only kept as a
  saved output if `savePixelGroupMap = TRUE`).
- `pixelGroupParameters` — a table of the site characteristics (climate polygon, dominant
  species, soil, elevation, etc.) associated with each pixel group.


|objectName           |objectClass |desc                                                                                                                                                                          |
|:--------------------|:-----------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|bbgcSpinup.ini       |list        |Biome-BGC initialization files for the spinup. Named list of parsed ini objects (as returned by BiomeBGCR::iniRead()), one per pixel group/scenario, named by pixel group id. |
|bbgc.ini             |list        |Biome-BGC initialization files. Named list of parsed ini objects (as returned by BiomeBGCR::iniRead()), one per pixel group/scenario, named by pixel group id.                |
|pixelGroupMap        |SpatRaster  |                                                                                                                                                                              |
|pixelGroupParameters |data.frame  |                                                                                                                                                                              |

# Links to other modules

`BiomeBGC_dataPrep` is typically the first module run in a Biome-BGC workflow — it has no
upstream module dependencies, and prepares inputs for `BiomeBGC_core`, which reads the
`bbgcSpinup.ini`/`bbgc.ini` files produced here to run the model. Model output from
`BiomeBGC_core` can in turn be validated against observed flux tower data using
`BiomeBGC_validationFluxTower`.

```mermaid
flowchart LR
    A[studyArea + optional inputs] --> B[preparePixelGroups]
    B --> C[prepareSpinupIni]
    C --> D[prepareIni]
    D --> E["bbgcSpinup.ini / bbgc.ini"]
    E --> F[BiomeBGC_core]
    F --> G[BiomeBGC_validationFluxTower]
```

# References
