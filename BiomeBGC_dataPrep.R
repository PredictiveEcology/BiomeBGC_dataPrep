## Everything in this file and any files in the R directory are sourced during `simInit()`;
## all functions and objects are put into the `simList`.
## To use objects, use `sim$xxx` (they are globally available to all modules).
## Functions can be used inside any function that was sourced in this module;
## they are namespaced to the module, just like functions in R packages.
## If exact location is required, functions will be: `sim$.mods$<moduleName>$FunctionName`.
defineModule(sim, list(
  name = "BiomeBGC_dataPrep",
  description = "Prepares inputs to run Biome-BGC.",
  keywords = "",
  authors = c(
    person("Dominique", "Caron", email = "dominique.caron@nrcan-rncan.gc.ca", role = c("aut", "cre")),
    person("Céline", "Boisvenue", email = "celine.boisvenue@nrcan-rncan.gc.ca", role = "ctb")
  ),
  childModules = character(0),
  version = list(BiomeBGC_dataPrep = "0.0.0.9000"),
  timeframe = as.POSIXlt(c(NA, NA)),
  timeunit = "year",
  citation = list("citation.bib"),
  documentation = list("NEWS.md", "README.md", "BiomeBGC_dataPrep.Rmd"),
  reqdPkgs = list("PredictiveEcology/SpaDES.core (>= 3.0.3)", "ggplot2", "PredictiveEcology/LandR@development",
                  "PredictiveEcology/BiomeBGCR@development", "elevatr", "terra", "rvest", "data.table",
                  "BioSIM", "geosphere", "ggpubr"),
  parameters = bindrows(
    defineParameter("carbonState", "numeric", c(0.001, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), NA, NA,
                    paste("11-number vector for initial carbon conditions:",
                          "1: peak leaf carbon to be attained during the first simulation year (kgC/m2)",
                          "2: peak stem carbon to be attained during the first year (kgC/m2)",
                          "3: initial coarse woody debris carbon (dead trees, standing or fallen) (kgC/m2)",
                          "4: initial litter carbon, labile pool (kgC/m2)",
                          "5: initial litter carbon, unshielded cellulose pool (kgC/m2)",
                          "6: initial litter carbon, shielded cellulose pool (kgC/m2)",
                          "7: initial litter carbon, lignin pool (kgC/m2)",
                          "8: soil carbon, fast pool (kgC/m2)",
                          "9: soil carbon, medium pool (kgC/m2)",
                          "10: soil carbon, slow pool (kgC/m2)",
                          "11: soil carbon, slowest pool (kgC/m2)"
                    )
    ),
    defineParameter("climModel", "character", "RCM4", NA, NA,
                    paste("A climatic model to extract meteorological data.",
                          "Either 'RCM4', 'GCM4', or 'Hadley'.")
    ),
    defineParameter("climateChangeOptions", "numeric", c(0, 0, 1, 1, 1), NA, NA,
                    paste("Entries in the CLIMATE_CHANGE section of the ini file.",
                          "The entries are: offset for Tmax, offset for Tmin",
                          "multiplier for prcp, multiplier for vpd, and muliplier",
                          "for srad.")
    ),
    defineParameter("co2scenario", "character", "RCP45", NA, NA,
                    paste("An representative concentration pathway for the co2",
                          "concentration trajectories and meteorological data.",
                          "Either 'RCP45' or 'RCP85'.")
    ),
    defineParameter("maxSpinupYears", "integer", 6000L, NA, NA,
                    paste("The maximum number of simulation for a spinup run.")
    ),
    defineParameter("metSpinupYears", "numeric", 40, NA, NA,
                    paste("The number of years used for the spinup.")
    ),
    defineParameter("NDepositionLevel", "numeric", c(1, NA, NA), NA, NA,
                    paste("A 3-number vector:",
                          "1) Keep nitrogen deposition level constant (0) or vary according to the time trajectory of CO2 mole fractions (1).",
                          "2) The reference year for N deposition (only used when N-deposition varies).",
                          "3) Industrial N deposition value.")
    ),
    defineParameter("nitrogenState", "numeric", c(0, 0), NA, NA,
                    paste("2-number vector for initial nitrogen conditions:",
                          "1: litter nitrogen associated with labile litter carbon pool (kgN/m2)",
                          "2: soil mineral nitrogen pool (kgN/m2)")
    ),
    defineParameter("outputVariables", "numeric", c(0, 3, 545, 641, 44, 620, 621), NA, NA,
                    paste("The indices of the daily output variable(s) requested.",
                          "There are >500 possible variables and are listed here:",
                          "https://raw.githubusercontent.com/PredictiveEcology/BiomeBGCR/refs/heads/development/src/Biome-BGC/src/bgclib/output_map_init.c.",
                          "The units of each variable are found here:",
                          "https://raw.githubusercontent.com/PredictiveEcology/BiomeBGCR/refs/heads/development/src/Biome-BGC/src/include/bgc_struct.h.")
    ),
    defineParameter("siteConstants", "numeric", c(NA, NA, NA, NA, NA, NA, NA, NA, NA), NA, NA,
                    paste("A vector with site information:",
                          "1: effective soil depth",
                          "2: sand percentage",
                          "3: silt percentage",
                          "4: clay percentage",
                          "5: site elevation in meters",
                          "6: site latitude in decimal degrees",
                          "7: site shortwave albedo",
                          "8: annual rate of atmospheric nitrogen deposition",
                          "9: annual rate of symbiotic+asymbiotic nitrogen fixation",
                          "The non-na constants will be retrieved in various sources.")
    ),
    defineParameter("savePixelGroupMap", "logical", FALSE, NA, NA,
                    paste("If TRUE, the objects pixelGroupMap will be saved.")
    ),
    defineParameter("waterState", "vector", c(NA, 0.5), NA, NA,
                    paste("2-number vector for initial water conditions:",
                          "1: initial snowpack water content (kg/m2)",
                          "2: intial soil water content as a proportion of saturation (DIM)",
                          "If set to NA, the initial snowpack water content will be retrieved by an external source.")
    ),
    defineParameter(".plots", "character", "screen", NA, NA,
                    "Used by Plots function, which can be optionally used here"),
    defineParameter(".plotInitialTime", "numeric", start(sim), NA, NA,
                    "Describes the simulation time at which the first plot event should occur."),
    defineParameter(".plotInterval", "numeric", NA, NA, NA,
                    "Describes the simulation time interval between plot events."),
    defineParameter(".saveInitialTime", "numeric", NA, NA, NA,
                    "Describes the simulation time at which the first save event should occur."),
    defineParameter(".saveInterval", "numeric", NA, NA, NA,
                    "This describes the simulation time interval between save events."),
    defineParameter(".studyAreaName", "character", NA, NA, NA,
                    "Human-readable name for the study area used - e.g., a hash of the study",
                    "area obtained using `reproducible::studyAreaName()`"),
    ## .seed is optional: `list('init' = 123)` will `set.seed(123)` for the `init` event only.
    defineParameter(".seed", "list", list(), NA, NA,
                    "Named list of seeds to use for each event (names)."),
    defineParameter(".useCache", "logical", FALSE, NA, NA,
                    "Should caching of events or module be used?")
  ),
  inputObjects = bindrows(
    expectsInput("climatePolygons", "SpatVector",
                 desc = paste("Polygons of homogeneous climate. By default,",
                              "ecodistricts are used.")
    ),
    expectsInput("CO2concentration", "data.frame",
                 desc = paste("CO2 concentration for each year.")
    ),
    expectsInput("dominantSpecies", "SpatRaster",
                 desc = paste(
                   "A raster with the leading tree species (speciesId).",
                   "Use to determine the ecophysiological constants.",
                   "By default, the NTEMS dominant tree species layer for the starting year is used.")
    ),
    expectsInput("ecophysiologicalConstants", "data.frame",
                 desc = paste(
                   "Ecophysiological constants. Columns are speciesId, species, PFT, and",
                   "the ecological constants (see template). By default,",
                   "ecophysiologicalConstants are extracted from White et al., 2000,",
                   "Hessl et al., 2004, and TRY.")
    ),
    expectsInput("elevation", "SpatRaster",
                 desc = paste(
                   "An elevation (m) raster. By default, the raster will be extracted from",
                   "AWS Terrain Tiles with the elevatr package."
                 ),
                 sourceURL = "https://registry.opendata.aws/terrain-tiles/"
    ),
    expectsInput("meteorologicalData", "list",
                 desc = paste("List of data.frames with the meteorological data",
                              "for each climate polygons. The units are `deg C`",
                              "for Tmax, Tmin, and Tday, `cm` for prcp, `Pa` for",
                              "VPD, `W/m^2` for srad, and `s` for daylen.")
    ),
    expectsInput("Ndeposition", "SpatRaster",
                 desc = paste(
                   "Raster(s) of total atmospheric N deposition (kgN/m2/yr).",
                   "If N deposition is variable two layers need to be provided,",
                   "one for N deposition at the start, of the simulation and a",
                   "second for N deposition at another timestep. The layer name",
                   "of the second raster needs to be the year of the data."
                 ),
                 sourceURL = "https://www.nature.com/articles/s41467-024-55606-y"
    ),
    expectsInput("NfixationRates", "SpatRaster",
                 desc = paste(
                   "Raster of annual rate of symbiotic + asymbiotic nitrogen fixation (kgN/m2/yr)."
                 ),
                 sourceURL = "https://www.sciencebase.gov/catalog/item/66a97480d34e07a119db3a37"
    ),
    expectsInput("rasterToMatch", "SpatRaster",
                 desc = paste("A raster defining the extent, resolution, projection of the",
                              "study area. The user needs to provide the rasterToMatch if",
                              "the studyArea is a polygon.")
    ),
    expectsInput("snowpackWaterContent", "SpatRaster",
                 desc = paste(
                   "Initial snowpack water content (kg/m2)."
                 ),
                 sourceURL = "https://climate-scenarios.canada.ca/?page=blended-snow-data"
    ),
    expectsInput("soilDepth", "SpatRaster",
                 desc = paste(
                   "A raster of effective soil depth (rooting zone depth) in m."
                 ),
                 sourceURL = "https://www.earthdata.nasa.gov/data/catalog/ornl-cloud-nacp-mstmip-unified-na-soilmap-1242-1"
    ),
    expectsInput("soilTextures", "SpatRaster",
                 desc = paste(
                   "A raster stack with layers representing the % of 'Sand', 'Silt', and 'Clay'.",
                   "The across-layers sum needs to equal to 1 for each pixels."
                 ),
                 sourceURL = "https://sis.agr.gc.ca/cansis/nsdb/psm/index.html"
    ),
    expectsInput("sppEquiv", "data.frame",
                 desc = paste(
                   "A data frame to link the leading species map to ecophysiological constants.",
                   "The columns are speciesId, species, genus, functional plant type.")
    ),
    expectsInput("studyArea", "SpatVector",
                 desc = paste("Polygons to use as the study area. Must be supplied by the user.",
                              "One polygon per study site.")
    )
  ),
  outputObjects = bindrows(
    createsOutput(
      objectName = "bbgcSpinup.ini",
      objectClass = "character",
      desc = paste(
        "Biome-BGC initialization files for the spinup.",
        "Path to the .ini files (one path per site/scenario)."
      )
    ),
    createsOutput(
      objectName = "bbgc.ini",
      objectClass = "character",
      desc =  paste(
        "Biome-BGC initialization files.",
        "Path to the .ini files (one path per site/scenario)."
      )
    ),
    createsOutput("pixelGroupMap", "SpatRaster", desc = paste("")),
    createsOutput("pixelGroupParameters", "data.frame", desc = paste(""))
  )
))

doEvent.BiomeBGC_dataPrep = function(sim, eventTime, eventType) {
  switch(
    eventType,
    init = {
      # if there are no treed-pixels, skip all events
      if (inherits(sim$dominantSpecies, "SpatRaster") &&  all(is.na(values(sim$dominantSpecies)))) {
        return(invisible(sim))
      }
      
      sim <- preparePixelGroups(sim)
      
      sim <- prepareSpinupIni(sim)
      
      sim <- prepareIni(sim)
      
      # schedule plotting
      if (anyPlotting(P(sim)$.plots)) sim <- scheduleEvent(sim, end(sim), "BiomeBGC_dataPrep", "plot", eventPriority = 12)
    },
    plot = {
      # Will save in a common BiomeBGC folder
      figPath <- file.path(outputPath(sim), "BiomeBGC_figures")
      
      # Climate plot
      metPlot <- climatePlot(sim$meteorologicalData)
      
      SpaDES.core::Plots(metPlot,
                         filename = "climatePlot",
                         path = figPath,
                         ggsaveArgs = list(width = 14, height = 5, units = "in", dpi = 300),
                         types = "png")
      
      
      # Raster of the climate polygon
      SpaDES.core::Plots(sim$climatePolygons,
                         filename = "climatePolygons",
                         fn = climatePolygonMap,
                         path = figPath,
                         deviceArgs = list(width = 7, height = 7, units = "in", res = 300),
                         types = "png")
      
    },
    warning(noEventWarning(sim))
  )
  return(invisible(sim))
}


### template for save events
Save <- function(sim) {
  # ! ----- EDIT BELOW ----- ! #
  # do stuff for this event
  sim <- saveFiles(sim)
  
  # ! ----- STOP EDITING ----- ! #
  return(invisible(sim))
}

preparePixelGroups <- function(sim) {
  message("Grouping pixels sharing parameters.")
  field <- "climatePolygonId"
  
  # tag if studyArea is a point vector
  SAisPolygon <- geomtype(sim$studyArea) == "polygons"
  
  if (SAisPolygon){
    
    pixelGroups <- prepPixelGroups(sim$dominantSpecies, sim$climatePolygons, sim$soilTexture, sim$soilDepth, sim$shortwaveAlbedo, sim$Ndeposition, sim$NfixationRates, sim$elevation, sim$snowpackWaterContent, sim$rasterToMatch) |> Cache()
    sim$pixelGroupParameters <- pixelGroups$pixelGroupParameters
    sim$pixelGroupMap <- pixelGroups$pixelGroupMap
    
    if(P(sim)$savePixelGroupMap){
      terra::writeRaster(sim$pixelGroupMap,
                         filename = file.path(outputPath(sim), "pixelGroupMap.tif"),
                         overwrite = TRUE)
    }
    
  } else {
    # dominant species
    if (inherits(sim$dominantSpecies, "SpatRaster")){
      # if the studyArea is points, extract values for each point
      dominantSpecies <- extract(sim$dominantSpecies, sim$studyArea)
      
      # If points falls in a non-treed pixel, find the closest pixel with a leading species
      i <- 1
      dominantSpeciesRast <- sim$dominantSpecies
      while (any(is.na(dominantSpecies[,2])) | i < 3){
        message("The study area falls in a non-treed pixel, using the leading species of close pixels.")
        message("Using distance: ", i, "cells.")
        dominantSpeciesRast <- focal(dominantSpeciesRast, w = 3, fun = "modal", na.policy = "only")
        dominantSpecies <- extract(dominantSpeciesRast, sim$studyArea)
        i <- i + 1
      }
      if(any(is.na(dominantSpecies[,2]))) {
        stop("The study area is further than 3 pixels from a treed pixel. Verify your inputs.")
      }
      speciesNames <- cats(sim$dominantSpecies)[[1]]$category
      dominantSpecies <- speciesNames[dominantSpecies[,2]]
    } else {
      dominantSpecies <- sim$dominantSpecies
    }
    
    latitudes <- project(crds(sim$studyArea), crs(sim$studyArea), "EPSG:4326")[,2]
    
    sim$pixelGroupParameters <- data.table(
      pixelGroup = 1:length(sim$studyArea),
      climatePolygon = extract(sim$climatePolygons, sim$studyArea)[field] |> unlist(),
      dominantSpecies = dominantSpecies,
      soilSandContent = extract(sim$soilTexture$sand, sim$studyArea, ID = FALSE) |> unlist(),
      soilClayContent = extract(sim$soilTexture$clay, sim$studyArea, ID = FALSE) |> unlist(),
      soilSiltContent = extract(sim$soilTexture$silt, sim$studyArea, ID = FALSE) |> unlist(),
      soilDepth = extract(sim$soilDepth, sim$studyArea, ID = FALSE) |> as.vector(),
      soilAlbedo = extract(sim$shortwaveAlbedo, sim$studyArea, ID = FALSE) |> unlist(),
      NdepositionT1 = extract(sim$Ndeposition[[1]], sim$studyArea, ID = FALSE) |> unlist(),
      NdepositionT2 = extract(sim$Ndeposition[[2]], sim$studyArea, ID = FALSE) |> as.vector(),
      NfixationRate = extract(sim$NfixationRates, sim$studyArea, ID = FALSE) |> unlist(),
      elevation = extract(sim$elevation, sim$studyArea, ID = FALSE) |> unlist(),
      latitude = round(latitudes, 1),
      snowPackWaterContent = extract(sim$snowpackWaterContent, sim$studyArea, ID = FALSE) |> unlist()
    )
    
    sim$pixelGroupMap <- rasterize(sim$studyArea, sim$soilTexture$sand)
  }
  return(invisible(sim))
}

prepareSpinupIni <- function(sim) {
  message("Creating ini files for the spinup.")
  iniTemplate <- iniRead(system.file("inputs/ini/template.ini", package = "BiomeBGCR"))
  
  # set sections that are shared across all pixelGroups
  ## Set TIME_DEFINE section
  iniTemplate <- iniSet(iniTemplate, "TIME_DEFINE", 1, P(sim)$metSpinupYears) # number of year in the metdata
  iniTemplate <- iniSet(iniTemplate, "TIME_DEFINE", 2, P(sim)$metSpinupYears) # number of simulation years
  iniTemplate <- iniSet(iniTemplate, "TIME_DEFINE", 3, start(sim) - P(sim)$metSpinupYears) #first simulation year
  iniTemplate <- iniSet(iniTemplate, "TIME_DEFINE", 4, 1) # 1 = spinup, 0 = normal simulation
  iniTemplate <- iniSet(iniTemplate, "TIME_DEFINE", 5, P(sim)$maxSpinupYears) # max spinup years
  
  ## Set CLIM_CHANGE section
  iniTemplate <- iniSet(iniTemplate, "CLIM_CHANGE", c(1:5), P(sim)$climateChangeOptions)
  
  ## Set CO2_CONTROL section
  # TODO: make sure that co2 is always constant for the spinup. If so, which year?
  iniTemplate <- iniSet(iniTemplate, "CO2_CONTROL", 1, 0) # Constant co2 concentration during spinup
  iniTemplate <- iniSet(iniTemplate, "CO2_CONTROL", 2, sim$CO2concentration[sim$CO2concentration$year == (start(sim)-P(sim)$metSpinupYears), "co2_ppm"])
  
  # Set C_STATE section
  iniTemplate <- iniSet(iniTemplate, "C_STATE", 1:11, P(sim)$carbonState)
  
  # Set N_STATE section
  iniTemplate <- iniSet(iniTemplate, "N_STATE", 1:2, P(sim)$nitrogenState)
  
  # Set OUTPUT_CONTROL section
  # TODO make sure this is what we want for the spinup
  iniTemplate <- iniSet(iniTemplate, "OUTPUT_CONTROL", 2:6,
                        c(0, # 1 = write daily output   0 = no daily output
                          0, # 1 = monthly avg of daily variables  0 = no monthly avg
                          0, # 1 = annual avg of daily variables   0 = no annual avg
                          0, # 1 = write annual output  0 = no annual output
                          1)) # for on-screen progress indicator
  
  # Set DAILY_OUTPUT section
  nDailyOutput <- length(P(sim)$outputVariables)
  # Rewrite, it is easier given that the size of the section varies
  iniTemplate[["DAILY_OUTPUT"]] <- rbind(iniTemplate[["DAILY_OUTPUT"]][1, ],
                                         c(nDailyOutput, "(int)", "number of daily variables to output"))
  iniTemplate[["DAILY_OUTPUT"]] <- rbind(
    iniTemplate[["DAILY_OUTPUT"]],
    data.frame(
      value = P(sim)$outputVariables,
      unit = c(0:(nDailyOutput -
                    1)),
      comment = getOutputDescription(P(sim)$outputVariables)
    )
  )
  
  # Set RESTART section
  iniTemplate <- iniSet(iniTemplate, "RESTART", c(1:4), c(0, 1, 0, 0))
  
  # Set RAMP_NDEP section: N deposition constant for the spinup
  iniTemplate <- iniSet(iniTemplate, "RAMP_NDEP", 1, 0)
  
  # Set the W_STATE section
  iniTemplate <- iniSet(iniTemplate, "W_STATE", 2, P(sim)$waterState[2])
  
  # Species lookup table linking species name and id
  species_lookup <- setNames(sim$sppEquiv$species, sim$sppEquiv$speciesId)
  # Name of the second reference year for N deposition
  Ndep_yr2 = ifelse(nlyr(sim$Ndeposition) == 2, names(sim$Ndeposition[[2]]), NA)
  
  # Prepare ini files for the spinup
  sim$bbgcSpinup.ini <- prepSpinupIni(
    pixelGroupParameters = sim$pixelGroupParameters,
    iniTemplate = iniTemplate,
    userParams = params(sim)$BiomeBGC_dataPrep,
    species_lookup = species_lookup,
    Ndep_yr2 = Ndep_yr2
  ) |> Cache(omitArgs = "userParams")
  return(invisible(sim))
}

prepareIni <- function(sim) {
  message("Creating ini files for the main simulation.")
  # Cache some objects to speedup the loop
  met_suffix <- paste0("_", P(sim)$climModel, P(sim)$co2scenario, "_",
                       start(sim) - P(sim)$metSpinupYears, end(sim), ".mtc43")
  pixGroupParams <- sim$pixelGroupParameters
  nPixelGroups <- nrow(sim$pixelGroupParameters)
  nyear <- end(sim) - start(sim) + 1 + P(sim)$metSpinupYears
  firstyear <- start(sim) - P(sim)$metSpinupYears
  co2fileName <- paste("co2",
                       start(sim)-P(sim)$metSpinupYears,
                       end(sim),
                       paste0(P(sim)$co2scenario, ".txt"),
                       sep = "_")
  co2filePath <-file.path("inputs", "co2", co2fileName)
  rampNdep <- P(sim)$NDepositionLevel[1]
  
  bbgc.ini <- lapply(seq_len(nPixelGroups), function(i){
    parameters <- pixGroupParams[i, ]
    # Start from the spinup ini
    ini <- sim$bbgcSpinup.ini[[as.character(parameters$pixelGroup)]]
    
    ## Set MET_INPUT section
    fileName <- tolower(paste0(
      parameters$climatePolygon,
      met_suffix
    ))
    ini <- iniSet(ini, "MET_INPUT", 1, file.path("inputs", "metdata", fileName))
    
    # Change the RESTART section
    ini <- iniSet(ini, "RESTART", c(1:4), c(1, 0, 0, 0))
    ini <- iniSet(ini, "RESTART", 5, file.path("inputs", "restart", paste0(parameters$pixelGroup, ".restart")))
    ini <- iniSet(ini, "RESTART", 6, file.path("inputs", "restart", paste0(parameters$pixelGroup, "_out.restart")))
    
    # Change the TIME_DEFINE section
    ini <- iniSet(ini, "TIME_DEFINE", 1, nyear) # number of year in the metdata
    ini <- iniSet(ini, "TIME_DEFINE", 2, nyear) # number of simulation years
    ini <- iniSet(ini, "TIME_DEFINE", 3, firstyear) #first simulation year
    ini <- iniSet(ini, "TIME_DEFINE", 4, 0) # 1 = spinup, 0 = normal simulation
    
    # Change the CO2 section
    ini <- iniSet(ini, "CO2_CONTROL", 1, 1)
    ini <- iniSet(ini, "CO2_CONTROL", 3, co2filePath)
    
    # Change the RAMP_NDEP section
    ini <- iniSet(ini, "RAMP_NDEP", 1, rampNdep)
    
    # Change OUTPUT_CONTROL section
    fileName <- file.path("outputs", paste0(parameters$pixelGroup, "_out"))
    ini <- iniSet(ini, "OUTPUT_CONTROL", 1, fileName)
    ini <- iniSet(ini, "OUTPUT_CONTROL", 2:6, c(
      1, # 1 = write daily output   0 = no daily output
      1, # 1 = monthly avg of daily variables  0 = no monthly avg
      1, # 1 = annual avg of daily variables   0 = no annual avg
      0, # 1 = write annual output  0 = no annual output
      0  # for on-screen progress indicator
    ))
    
    return(ini)
  })
  names(bbgc.ini) <- sim$pixelGroupParameters$pixelGroup
  sim$bbgc.ini <- bbgc.ini
  
  return(invisible(sim))
}

climatePlot <- function(metData) {
  pal <- rainbow(n = length(metData))
  
  # for each climate polygon, calculate annual precipitation, and average temperature
  metData <- lapply(metData, function(climPolygonData){
    if(!inherits(climPolygonData, "data.table")) climPolygonData <- as.data.table(climPolygonData)
    climPolygonData[ ,.(tavg = mean(tday), annPrcp = sum(prcp) * 10), by = year]
  })
  
  # get into a single data.table
  metData <- rbindlist(metData, idcol = "climatePolygon")
  
  TempPlot <- ggplot(metData) +
    geom_line(aes(x = year, y = tavg, color = climatePolygon), linewidth = 0.75) +
    labs(x = "Year", y = "Daytime average temperature (°C)", color = "Climate polygon") +
    theme_bw() +
    scale_color_manual(values = pal)
  
  PrecipPlot <- ggplot(metData) +
    geom_line(aes(x = year, y = annPrcp, color = climatePolygon), linewidth = 0.75) +
    labs(x = "Year", y = "Annual precipitation (mm)", color = "Climate polygon") +
    theme_bw() +
    scale_color_manual(values = pal)
  
  
  p <- ggpubr::ggarrange(TempPlot, PrecipPlot,  common.legend = TRUE, legend = "right")
  
  return(p)
}

climatePolygonMap <- function(climatePolygons){
  pal <- rainbow(n = length(climatePolygons))
  
  if (!("climatePolygonId" %in% names(climatePolygons))){
    climatePolygons$climatePolygonId <- c(1:length(climatePolygons))
  }
  
  p <- terra::plot(climatePolygons, "climatePolygonId", col = pal, plg = list(title="Climate polygon"))
  return(p)
}

.inputObjects <- function(sim) {
  dPath <- asPath(inputPath(sim), 1)
  message(currentModule(sim), ": using dataPath '", dPath, "'.")
  # Study area needs to be either points or a polygon
  if (!suppliedElsewhere('studyArea', sim)) {
    
    stop("studyArea must be provided.")
    
  }
  
  # Check that the studyArea is either a SpatVector polygon or point
  if (geomtype(sim$studyArea) == "polygons"){
    
    if (!suppliedElsewhere('rasterToMatch', sim)) {
      
      stop("Please provide a rasterToMatch when studyArea is a polygon.")
      
    } else {
      rstTo <- sim$rasterToMatch
      polyTo <- sim$studyArea
      treedPixels <- !is.na(values(sim$rasterToMatch))
    }
    
  } else if (geomtype(sim$studyArea) == "points"){
    
    # Used to crop/mask/project the inputs
    polyTo <- buffer(sim$studyArea, 10^4)
    rstTo <- terra::rast(polyTo, res = res(sim$rasterToMatch))
    values(rstTo) <- 1
    treedPixels <- 1
    
  } else {
    
    stop("studyArea must be a SpatVector polygon or points")
    
  }
  
  # Dominant species layer
  # Default source: NTEMS dominant species layer for the 1st year of simulation
  if (!suppliedElsewhere('dominantSpecies', sim)) {
    
    yearToUse <- max(min(start(sim), 2022), 1984)
    
    if (yearToUse != start(sim)){
      message("NTEMS dominant species layer is not available for ", start(sim),
              ", using layer for ", yearToUse)
    }
    
    sim$dominantSpecies <- prepNTEMSDominantSpecies(
      year = yearToUse,
      destinationPath = dPath,
      cropTo = rstTo,
      projectTo = rstTo,
      maskTo = rstTo
    ) |> Cache()
    
    treedPixels <- !is.na(values(sim$dominantSpecies))
    
    # If there are no pixels with trees, skip.
    if (all(!treedPixels)){
      message("No treed-pixel in the study area. No simulation will be made by Biome-BGC")
      return(invisible(sim))
    }
    
  }
  
  # Climate polygons: Climate is assumed to be homogeneous within polygons
  # Default source: Canadian ecodistrict
  if (!suppliedElsewhere('climatePolygons', sim)) {
    sim$climatePolygons <- prepInputs(
      targetFile = "ecodistricts.shp",
      url = "https://sis.agr.gc.ca/cansis/nsdb/ecostrat/district/ecodistrict_shp.zip",
      destinationPath = dPath,
      projectTo = rstTo,
      fun = "terra::vect"
    ) |>
      Cache()
    sim$climatePolygons$climatePolygonId <- sim$climatePolygons$ECODISTRIC
    
    # keeps the polygons that touches the studyarea
    rel <- terra::relate(
      sim$climatePolygons,
      sim$studyArea,
      relation = "intersects"
    )
    poly_indices <- which(rowSums(rel) > 0)
    
    sim$climatePolygons <- sim$climatePolygons[poly_indices, ]
    
    # if dominantSpecie is a raster
    if (inherits(sim$dominantSpecies, "SpatRaster")){
      forestedClimatePolygons <- extract(sim$dominantSpecies, sim$climatePolygons, fun = mean, na.rm = TRUE, ID = FALSE)
      forestedClimatePolygons <- !is.na(forestedClimatePolygons[ ,1])
      sim$climatePolygons <- sim$climatePolygons[forestedClimatePolygons, ]
    }
    
  }
  
  # Table to link the dominant species to traits of White et al., 2000
  if (!suppliedElsewhere('sppEquiv', sim)) {
    sppEquiv <- LandR::sppEquivalencies_CA[, c("LandR", "Latin_full", "Type")]
    sppEquiv <- sppEquiv[sppEquiv$Latin_full != "",]
    sppEquiv$genus <- sub(" .*", "", sppEquiv$Latin_full)
    sppEquiv$PFT <- ifelse(sppEquiv$Type == "Conifer", "enf", "dbf")
    sppEquiv <- data.frame(
      speciesId = sppEquiv$LandR,
      species = sppEquiv$Latin_full,
      genus = sppEquiv$genus,
      PFT = sppEquiv$PFT
    )
    if (inherits(sim$dominantSpecies, "SpatRaster")){
      speciesIdInStudyArea <- unique(values(sim$dominantSpecies)) |> na.omit()
      speciesInStudyArea <- cats(sim$dominantSpecies)[[1]][speciesIdInStudyArea,"category"]
    } else {
      speciesInStudyArea <- sim$dominantSpecies
    }
    sim$sppEquiv <- sppEquiv[match(speciesInStudyArea, sppEquiv$speciesId),]
  }
  
  # Table of ecophysiological constants of each species Id
  if (!suppliedElsewhere('ecophysiologicalConstants', sim)) {
    
    sim$ecophysiologicalConstants <- prepEPC(
      url = "https://drive.google.com/file/d/1ffAiI9_8cR8nUOXWiWbEa59vOtqEx_ii/view?usp=sharing",
      sppEquiv = sim$sppEquiv,
      destinationPath = dPath
    ) |> Cache()
    
  }
  
  # Soil texture (% sand, % silt, % clay)
  # Default sources: CanSIS Soil Landscape Grids of Canada
  # Using the 15-30cm depth layer
  if (!suppliedElsewhere('soilTexture', sim)) {
    
    sim$soilTexture <- prepSoilTexture(
      destinationPath = dPath,
      to = rstTo,
      treedPixels = treedPixels
    ) |> Cache()
    
  }
  
  # Soil Depth
  # Default source: ORNL NACP MsTMIP
  if (!suppliedElsewhere('soilDepth', sim)) {
    
    sim$soilDepth <- prepSoilDepth(
      destinationPath = dPath,
      to = rstTo,
      treedPixels = treedPixels
    ) |> Cache()
    
  }
  
  # Elevation raster
  # Default source: Amazon Web Services Terrain Tiles
  if (!suppliedElsewhere('elevation', sim)) {
    
    sim$elevation <- prepElevation(
      studyArea = sim$studyArea,
      to = rstTo
    ) |> Cache()
    
  }
  
  # Total N deposition
  # Default source: ADAGIO project, Robichaud et al.,2020: (https://doi.org/10.1016/j.atmosenv.2025.121074; https://doi.org/10.1016/j.atmosenv.2025.121656)
  if (!suppliedElsewhere('Ndeposition', sim)) {
    year1 <- max(start(sim), 2015)
    year2 <- min(end(sim), 2020)
    sim$Ndeposition <-  prepNdeposition(
      destinationPath = dPath,
      to = rstTo,
      year1 = year1,
      year2 = year2,
      treedPixels = treedPixels
    ) |> Cache()
    names(sim$Ndeposition) <- c(year1, year2)
  }
  
  # Total N fixation rates
  # Default source Reis Ely et al., 2025: https://doi.org/10.1038/s41597-025-05131-4
  if (!suppliedElsewhere('NfixationRates', sim)) {
    sim$NfixationRates <- prepNfixation(
      destinationPath = dPath,
      to = rstTo,
      treedPixels = treedPixels
    ) |> Cache()
    
  }
  
  # Initial snowpack water content
  # Default source: ECC snow water equivalent (SWE) over the Northern Hemisphere
  # Methods: Mudryk et al., 2015: https://doi.org/10.1175/JCLI-D-15-0229.1
  if (!suppliedElsewhere('snowpackWaterContent', sim)) {
    
    # data is available for 1981-2020
    yearToUse <- min(max(start(sim), 1981), 2020)
    if(yearToUse != start(sim)){
      message("Snowpack water content data is not available for ",
              start(sim), ", using data of ", yearToUse)
    }
    
    # Get data
    sim$snowpackWaterContent <- prepSnowpackWaterContent(
      destinationPath = dPath,
      rstTo = rstTo,
      polyTo = polyTo,
      year = yearToUse,
      treedPixels = treedPixels
    ) |> Cache()
    
  }
  
  # Shortwave Albedo
  # Default source: Based on SCANFI landcover and albedo of land cover type in
  # Gao et al., 2005 (https://doi.org/10.1029/2004JD005190)
  if (!suppliedElsewhere('shortwaveAlbedo', sim)) {
    lcc <- prepInputs(
      url = "https://ftp.maps.canada.ca/pub/nrcan_rncan/Forests_Foret/SCANFI/v1/SCANFI_att_nfiLandCover_SW_2020_v1.2.tif",
      destinationPath = dPath,
      projectTo = rstTo,
      maskTo = polyTo,
      method = "near",
      overwrite = TRUE
    ) |> Cache()
    albedoTable <- rvestAlbedoTable(dPath) |> Cache()
    sim$shortwaveAlbedo <- lccToAlbedo(lcc, albedoTable, rstTo) |> Cache()
  }
  
  # Meteorological data
  # Default source: BioSIM
  if (!suppliedElsewhere('meteorologicalData', sim)) {
    
    sim$meteorologicalData <- prepClimate(
      climatePolygons = sim$climatePolygons,
      simStartYear = start(sim),
      simEndYear = end(sim),
      nSpinupYears = P(sim)$metSpinupYears,
      scenario = P(sim)$co2scenario,
      climModel = P(sim)$climModel,
      destinationPath= dPath
    ) |> Cache()
    
  }
  
  # CO2 atmospheric concentration
  # Default source: Emission data for the different RCPs downloaded from
  # Folini et al., 2025: https://doi.org/10.1093/restud/rdae011
  if (!suppliedElsewhere('CO2concentration', sim)) {
    
    sim$CO2concentration <- prepCo2Concentration(
      firstYear = start(sim)-P(sim)$metSpinupYears,
      lastYear = end(sim),
      scenario = P(sim)$co2scenario,
      destinationPath= dPath
    ) |> Cache()
    
  }
  
  return(invisible(sim))
}

