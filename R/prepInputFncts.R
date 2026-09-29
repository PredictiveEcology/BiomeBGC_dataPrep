## Functions used to in the .inputObjects event:
# prepNTEMSDominantSpecies
# prepSoilTexture
# prepNdeposition
# rvestAlbedoTable
# prepCo2Concentration
# prepEPC
# prepClimate
# prepElevation
# prepSoilDepth
# prepNfixation
# prepSnowpackWaterContent

# Extract dominant species from NTEMS layers
prepNTEMSDominantSpecies <- function(year, destinationPath, cropTo, projectTo, maskTo, method = "mode"){
  # prepare url and targetFile for prepInput call
  domSppURL <- paste0("https://opendata.nfis.org/downloads/forest_change/CA_Tree_Species_Classification_", year, ".zip")
  domSppTF <- paste0("CA_Forest_Tree_Species_", year, ".tif")
  
  # prepInput
  dominantSpecies <- prepInputs(
    targetFile = domSppTF,
    url = domSppURL,
    destinationPath = destinationPath,
    cropTo = cropTo,
    projectTo = projectTo,
    maskTo = maskTo,
    method = method,
    overwrite = TRUE
  )
  # set 0 to NA
  NAflag(dominantSpecies) <- 0
  
  # Transform NTEMS code to speciesCode
  cls <- unique(LandR::sppEquivalencies_CA[, c("NTEMS_Species_Code", "LandR")]) |> na.omit()
  names(cls) <- c("id", "category")
  levels(dominantSpecies) <- cls
  
  return(dominantSpecies)
}

# Extract % of sand, % of clay and % of silt from CanSIS dataset
# Takes the average across layers 0-30cm
prepSoilTexture <- function(destinationPath, to, treedPixels){
  ## Sand %
  # layer 0-5 cm
  sand0_5 <- prepInputs(
    url = "https://sis.agr.gc.ca/cansis/nsdb/psm/Sand/Sand_X0_5_cm_100m1980-2000v1.tif",
    targetFile = "Sand_X0_5_cm_100m1980-2000v1.tif",
    destinationPath = destinationPath,
    cropTo = to,
    projectTo = to,
    overwrite = TRUE
  ) |> Cache()
  sand0_5 <- fillMissingValues(sand0_5, treedPixels, "Sand content 0-5 cm") |> Cache()
  sand0_5 <- maskTo(sand0_5, to) |> Cache()
  
  sand5_15 <- prepInputs(
    url = "https://sis.agr.gc.ca/cansis/nsdb/psm/Sand/Sand_X5_15_cm_100m1980-2000v1.tif",
    targetFile = "Sand_X5_15_cm_100m1980-2000v1.tif",
    destinationPath = destinationPath,
    cropTo = to,
    projectTo = to,
    overwrite = TRUE
  ) |> Cache()
  sand5_15 <- fillMissingValues(sand5_15, treedPixels, "Sand content 5-15 cm") |> Cache()
  sand5_15 <- maskTo(sand5_15, to) |> Cache()
  
  sand15_30 <- prepInputs(
    url = "https://sis.agr.gc.ca/cansis/nsdb/psm/Sand/Sand_X15_30_cm_100m1980-2000v1.tif",
    targetFile = "Sand_X15_30_cm_100m1980-2000v1.tif",
    destinationPath = destinationPath,
    cropTo = to,
    projectTo = to,
    overwrite = TRUE
  ) |> Cache()
  sand15_30 <- fillMissingValues(sand15_30, treedPixels, "Sand content 15-30 cm") |> Cache()
  sand15_30 <- maskTo(sand15_30, to) |> Cache()
  
  sand <- round((5/30) * sand0_5 + (10/30) * sand5_15 + (15/30) * sand15_30, digit = -1)
  
  clay0_5 <- prepInputs(
    url = "https://sis.agr.gc.ca/cansis/nsdb/psm/Clay/Clay_X0_5_cm_100m1980-2000v1.tif",
    targetFile = "Clay_X0_5_cm_100m1980-2000v1.tif",
    destinationPath = destinationPath,
    cropTo = to,
    projectTo = to,
    overwrite = TRUE
  ) |> Cache()
  clay0_5 <- fillMissingValues(clay0_5, treedPixels, "Clay content 0-5 cm") |> Cache()
  clay0_5 <- maskTo(clay0_5, to) |> Cache()
  
  clay5_15 <- prepInputs(
    url = "https://sis.agr.gc.ca/cansis/nsdb/psm/Clay/Clay_X5_15_cm_100m1980-2000v1.tif",
    targetFile = "Clay_X5_15_cm_100m1980-2000v1.tif",
    destinationPath = destinationPath,
    cropTo = to,
    projectTo = to,
    overwrite = TRUE
  ) |> Cache()
  clay5_15 <- fillMissingValues(clay5_15, treedPixels, "Clay content 5-15 cm") |> Cache()
  clay5_15 <- maskTo(clay5_15, to) |> Cache()
  
  clay15_30 <- prepInputs(
    url = "https://sis.agr.gc.ca/cansis/nsdb/psm/Clay/Clay_X15_30_cm_100m1980-2000v1.tif",
    targetFile = "Clay_X15_30_cm_100m1980-2000v1.tif",
    destinationPath = destinationPath,
    cropTo = to,
    projectTo = to,
    overwrite = TRUE
  ) |> Cache()
  clay15_30 <- fillMissingValues(clay15_30, treedPixels, "Clay content 15-30 cm") |> Cache()
  clay15_30 <- maskTo(clay15_30, to) |> Cache()
  
  clay <- round((5/30) * clay0_5 + (10/30) * clay5_15 + (15/30) * clay15_30, digit = -1)
  
  silt <- 100 - (sand + clay)
  soilTexture <- c(sand, silt, clay)
  names(soilTexture) <- c("sand", "silt", "clay")
  return(soilTexture)
}

# Extract N-deposition data for 2 years.
prepNdeposition <- function(destinationPath, to, year1, year2, treedPixels){
  # Units are KgN/yr/ha. Biome-BGC takes KgN/yr/m2
  Ndeposition1 <- prepInputs(
    targetFile = "2014_2015_2016_annual_total_deposition_of_nitrogen.tif",
    overwrite = TRUE,
    url = "https://drive.google.com/file/d/1Dnn0OTRdyGIhSU0b512LJB3k4wMg6n4b/view?usp=sharing",
    cropTo = to,
    projectTo = to,
    destinationPath = destinationPath,
    fun = "terra::rast"
  )
  
  # reprojecting can create holes
  # fill treed pixels without N deposition data with focal()
  Ndeposition1 <- fillMissingValues(Ndeposition1, treedPixels, "N deposition rates in the first timestep.")
  # mask to study area
  Ndeposition1 <- maskTo(Ndeposition1, to) |> round()
  
  # N deposition for the second time step
  Ndeposition2 <- prepInputs(
    targetFile = "2019_2020_2021_annual_total_deposition_of_nitrogen.tif",
    overwrite = TRUE,
    url = "https://drive.google.com/file/d/1cUlrVHR8ePKk_i5oPYZfI8DJHpVPwIcW/view?usp=sharing",
    projectTo = to,
    destinationPath = destinationPath,
    fun = "terra::rast"
  )
  
  # reprojecting can create holes
  # fill treed pixels without N deposition data with focal()
  Ndeposition2 <- fillMissingValues(Ndeposition2, treedPixels, "N deposition rates in the second timestep.")
  # mask to study area
  Ndeposition2 <- maskTo(Ndeposition2, to) |> round()
  
  # convert from kg/ha/yr to kg/m2/yr
  Ndeposition <- c(Ndeposition1/10000, Ndeposition2/10000)
  names(Ndeposition) <- as.character(c(year1, year2))
  
  return(Ndeposition)
}

# Get the albedo per land cover
rvestAlbedoTable <- function(destinationPath){
  # extract Table 1 of Gao et al., 2005 (https://doi.org/10.1029/2004JD005190)
  url <- "https://drive.google.com/file/d/1jjSg_xRNBLYoEyQx15nzEv8GgX4QMWbZ/view?usp=sharing"
  # GaoEtAl2005 <- read_html(url)
  # tables <- GaoEtAl2005 %>% html_table(fill = TRUE)
  # table1 <- tables[[1]]
  table1 <- prepInputs(targetFile = "albedoTable.csv",
                       url = url,
                       destinationPath = destinationPath)
  
  # Only keep the snow-free shortwave albedo entries
  shortwaveAlbedo <- table1[c(25:33), c(2,3,5,7,9)]
  
  # Add column names
  names(shortwaveAlbedo) <- c("IGBPclass", "lat6070", "lat5060", "lat4050", "lat3040")
  
  # Fix missing entries, set to NA
  shortwaveAlbedo[shortwaveAlbedo=="–"] <- NA
  
  # Convert entries to numeric
  shortwaveAlbedo[, c(2:5)] <- apply(shortwaveAlbedo[, c(2:5)], MARGIN = 2, as.numeric)
  
  return(as.data.frame(shortwaveAlbedo))
}

# Get the co2 concentration for a period for different representative concentration pathways (RCPs)
prepCo2Concentration <- function(firstYear, lastYear, scenario, destinationPath){
  dir.create(file.path(destinationPath, "co2"), showWarnings = FALSE)
  if (!(scenario %in% c("RCP26", "RCP45", "RCP60", "RCP85"))) {
    stop(
      "Available representative concentration pathways for co2 concentration ",
      "are RCP26, RCP45, RCP60, or RCP85"
    )
  }
  targetFile <- paste0(scenario, "_MIDYR_CONC.DAT")
  url <- paste0(
    "https://raw.githubusercontent.com/ClimateChangeEcon/Climate_in_Climate_Economics/refs/heads/main/calibration_data/EmiAndConcData/",
    targetFile
  )
  co2concentrations <- prepInputs(
    targetFile = targetFile,
    url = url,
    fun = {
      co2Data <- read.table(targetFile, skip = 39)
      co2Data <- co2Data[, c(1, 4)]
      co2Data
    },
    destinationPath = destinationPath,
    overwrite = TRUE
  ) |> Cache()
  yearToKeep <- firstYear <= co2concentrations[,1] & co2concentrations[,1] <= lastYear
  co2concentrations <- co2concentrations[yearToKeep, ]
  fileName <- paste("co2", firstYear, lastYear, paste0(scenario, ".txt"), sep = "_")
  CO2write(co2concentrations,
           fileName = file.path(destinationPath, "co2", fileName))
  names(co2concentrations) <- c("year", "co2_ppm")
  return(co2concentrations)
}

#
prepEPC <- function(url, sppEquiv, destinationPath){
  # create a folder for epc in the destinationPath
  dir.create(file.path(destinationPath, "epc"), showWarnings = FALSE)
  # read epc
  epc <- prepInputs(targetFile = "defaultEPC.csv",
                    url = url,
                    destinationPath = destinationPath,
                    fun = "data.table::fread",
                    check.names = TRUE,
                    overwrite = TRUE,
                    purge = 7)
  
  # keep only the lines for the species in study
  epc <- epc[epc$speciesId %in% sppEquiv$speciesId, ]
  
  # Write the species-level epcs in the destinationPath/epc folder
  apply(epc, MARGIN = 1, epcWrite2, destinationPath = destinationPath)
  
  return(epc)
}

# Extract the meteorological data
prepClimate <- function(climatePolygons, simStartYear, simEndYear, nSpinupYears, scenario, climModel, destinationPath){
  # define the first year to extract climate
  firstYear <- simStartYear - nSpinupYears
  
  # Create a folder where metdata will be saved
  dir.create(file.path(destinationPath, "metdata"), showWarnings = FALSE)
  
  climOut <- list()
  # Process one climate polygon at a time
  id <- climatePolygons$climatePolygonId
  for (climatePolygon_i in id){
    climOut[[as.character(climatePolygon_i)]] <- prepClimateSinglePolygon(
      climatePolygon = climatePolygons[climatePolygons$climatePolygonId == climatePolygon_i, ],
      id = climatePolygon_i,
      firstYear = firstYear,
      simStartYear = simStartYear,
      simEndYear = simEndYear,
      scenario,
      climModel,
      destinationPath = destinationPath
    ) |> Cache(omitArgs = "climatePolygon")
  }
  return(climOut)
}

prepClimateSinglePolygon <- function(climatePolygon, id, firstYear, simStartYear, simEndYear, scenario, climModel, destinationPath){
  # get latitude and longitude
  climatePoint <- spatSample(climatePolygon, 1)
  
  while(length(climatePoint) != 1){
    climatePoint <- spatSample(climatePolygon, 1)
  }
  latlon <- project(crds(climatePoint), crs(climatePolygon), "EPSG:4326")
  lon <- latlon[,1]
  lat <- latlon[,2]
  
  # get climate from BioSim
  climate <- generateWeather(
    modelNames = c("Climatic_Daily", "VaporPressureDeficit_Daily"),
    fromYr = firstYear,
    toYr = simEndYear,
    id = 1,
    latDeg = lat,
    longDeg = lon,
    rcp = scenario,
    climModel = climModel,
    additionalParms = NULL
  )
  
  # format climate data, 1 ecodistrict at a time
  climate <- lapply(climate, FUN = function(x){
    # BiomeBGC do not simulate Feb 29 (always 365 day/yr)
    x <- x[x$Month != 2 | x$Day != 29,]
    x
  })
  
  daylen <- daylength(lat, 1:365) * 60 * 60
  
  climate <- data.frame(
    year = climate[["Climatic_Daily"]]$Year,
    yday = 1:365,
    tmax = climate[["Climatic_Daily"]]$Tmax,
    tmin = climate[["Climatic_Daily"]]$Tmin,
    tday = climate[["Climatic_Daily"]]$Tair,
    prcp = round(climate[["Climatic_Daily"]]$Prcp/10, digits = 2), # from mm to cm
    vpd = round(climate[["VaporPressureDeficit_Daily"]]$DaylightVPD * 100, digits = 2), # from hPa to Pa
    srad = climate[["Climatic_Daily"]]$SRad,
    daylen = daylen,
    spinup = climate[["Climatic_Daily"]]$Year < simStartYear
  )
  
  # Sometimes, there is an artifact, making vpd unreasonably high
  while (any(climate$vpd > 10^4)) {
    # for the vpd exceeding 10 kPa, replace by the mean of the timestep before and after
    toReplace <- which(climate$vpd > 10^4)
    for (j in toReplace){
      if (j == 1){
        climate$vpd[j] <- climate$vpd[j+1]
      } else if (j == length(climate$vpd)) {
        climate$vpd[j] <- climate$vpd[j-1]
      } else {
        climate$vpd[j] <- (climate$vpd[j+1] + climate$vpd[j-1]) / 2
      }
      
    }
  }
  
  spinupFileName <- tolower(paste0(
    id,
    "_spinup.mtc43"
  ))
  spinupFileName <- file.path(destinationPath, "metdata", spinupFileName)
  
  metWrite(
    metData = climate[climate$spinup, c(1:10)],
    fileName = spinupFileName,
    siteName  = paste0("Climate Polygon: ", id),
    dataSource = paste(climModel, scenario, sep = ": ")
  )
  
  # Met data for main simulation
  fileName <- tolower(paste0(
    id,
    "_",
    climModel,
    scenario,
    "_",
    firstYear,
    simEndYear,
    ".mtc43"
  ))
  fileName <- file.path(destinationPath, "metdata", fileName)
  
  metWrite(
    metData = climate[, c(1:10)],
    fileName = fileName,
    siteName  = paste0("Climate Polygon: ", id),
    dataSource = paste(climModel, scenario, sep = ": ")
  )
  
  return(climate)
  
}

# Extract elevation raster
prepElevation <- function(studyArea, to){
  # get data from Amazon Web Services Terrain Tiles
  elevation <-  get_elev_raster(
    locations = sf::st_as_sf(studyArea),
    z = 9
  )
  
  # Crop and project to raster
  elevation <- postProcessTo(
    rast(elevation),
    to = to
  )
  
  # round to the nearest 50m
  return(50 * round(elevation/50))
}


# Extract soil depth raster
prepSoilDepth <- function(destinationPath, to, treedPixels){
  
  # Default source: ORNL NACP MsTMIP
  soilDepth <- prepInputs(
    targetFile = "Unified_NA_Soil_Map_Maximum_Soil_Depth.tif",
    overwrite = TRUE,
    url = "https://drive.google.com/file/d/1XviKnfo1JjVaeVl95Il4Hh7DNZp6IPvn/view?usp=sharing",
    destinationPath = destinationPath,
    to = to,
    fun = "terra::rast"
  )
  
  # fill treed pixels without soil depth data with focal()
  soilDepth <- fillMissingValues(soilDepth, treedPixels, "soil depth")
  
  # transfer from cm to m and round to the 0.1 m
  soilDepth <- round(soilDepth / 100, digits = 1)
  
  # mask
  soilDepth <- maskTo(soilDepth, to)
  
  return(soilDepth)
}

# Extract N fixation raster
# Default source Reis Ely et al., 2025: https://doi.org/10.1038/s41597-025-05131-4
prepNfixation <- function(destinationPath, to, treedPixels){
  NfixationRates <- prepInputs(
    targetFile = "BNF_total_central_0.004.tif",
    overwrite = TRUE,
    url = "https://drive.google.com/file/d/1AVZvcSBPCuDLagfGsfLbeYkmRl5S5G_d/view?usp=sharing",
    destinationPath = destinationPath,
    to = to,
    fun = "terra::rast"
  )
  
  # fill treed pixels without soil depth data with focal()
  NfixationRates <- fillMissingValues(NfixationRates, treedPixels, "N fixation rates")
  
  # convert from kg/ha/yr to kg/m2/yr
  NfixationRates <- round(NfixationRates)/10000
  
  # mask
  NfixationRates <-maskTo(NfixationRates, to)
  
  return(NfixationRates)
}

# Extract snowpack water equivalent
# Default source: ECC snow water equivalent (SWE) over the Northern Hemisphere
# Methods: Mudryk et al., 2015: https://doi.org/10.1175/JCLI-D-15-0229.1
# data is available for 1981-2020
prepSnowpackWaterContent <- function(destinationPath, rstTo, polyTo, year, treedPixels){
  # Get data
  snowpackWaterContent <- prepInputs(
    targetFile = "swe_monthly_mm_1981-2020.nc",
    url = "https://climate-scenarios.canada.ca/files/blended_snow_2024/swe_monthly_mm_1981-2020.zip",
    fun = "terra::rast",
    destinationPath = destinationPath,
    cropTo = rstTo,
    overwrite = TRUE
  )
  # Use the average for January of the first year.
  layerToKeep <- which(terra::time(snowpackWaterContent, format = "days") == paste(year, "01", "16", sep = "-"))
  
  snowpackWaterContent <- postProcessTo(
    snowpackWaterContent[[layerToKeep]],
    projectTo = rstTo,
    maskTo = polyTo
  )
  snowpackWaterContent <- fillMissingValues(snowpackWaterContent, treedPixels, "snowpack water content")
  
  snowpackWaterContent <- round(snowpackWaterContent, -1)
  
  terra::units(snowpackWaterContent) <- "kg/m^2"
  
  return(snowpackWaterContent)
}

prepPixelGroups <- function(dominantSpecies, climatePolygons, soilTexture, soilDepth, shortwaveAlbedo, Ndeposition, NfixationRates, elevation, snowpackWaterContent, rasterToMatch){
  
  # if the studyArea is a polygon, extract values for each cell
  if (inherits(dominantSpecies, "SpatRaster")){
    dominantSpeciesInPixels <- values(dominantSpecies, drop = TRUE)
    speciesNames <- cats(dominantSpecies)[[1]]$category
    dominantSpeciesInPixels <- speciesNames[dominantSpeciesInPixels]
  } else {
    dominantSpeciesInPixels <- dominantSpecies
  }
  latitudes <- project(crds(rasterToMatch, na.rm = F), crs(rasterToMatch), "EPSG:4326")[,2]
  latitudes <- 2 * round(latitudes / 2, digits = 1)
  pixelGroupParameters <- data.table(
    pixelIndex = 1:ncell(rasterToMatch),
    climatePolygon = values(rasterize(climatePolygons, rasterToMatch, field = "climatePolygonId")),
    dominantSpecies = dominantSpeciesInPixels,
    soilSandContent = values(soilTexture$sand),
    soilClayContent = values(soilTexture$clay),
    soilSiltContent = values(soilTexture$silt),
    soilDepth = values(soilDepth),
    soilAlbedo = values(shortwaveAlbedo),
    NdepositionT1 = values(Ndeposition[[1]]),
    NdepositionT2 = values(Ndeposition[[2]]),
    NfixationRate = values(NfixationRates),
    elevation = values(elevation),
    latitude = latitudes,
    snowPackWaterContent = values(snowpackWaterContent)
  )
  .desired_cols <- c(
    "pixelIndex", "climatePolygon", "dominantSpecies", "soilSandContent",
    "soilClayContent", "soilSiltContent", "soilDepth", "soilAlbedo",
    "NdepositionT1", "NdepositionT2", "NfixationRate", "elevation",
    "latitude", "snowPackWaterContent"
  )
  setnames(pixelGroupParameters, .desired_cols)
  nonForested <- is.na(pixelGroupParameters$dominantSpecies)
  pixelGroupParameters[nonForested, names(pixelGroupParameters) := NA]
  
  cols <- setdiff(names(pixelGroupParameters), "pixelIndex")
  
  pixelGroupParameters[, "pixelGroup"] <- LandR::generatePixelGroups(
    pixelGroupParameters,
    maxPixelGroup = 0,
    columns = cols
  )
  
  pixelGroupMap <- copy(rasterToMatch)
  values(pixelGroupMap) <- pixelGroupParameters[, "pixelGroup"]
  
  cols <- c(cols, "pixelGroup")
  pixelGroupParameters<- unique(
    pixelGroupParameters[,  ..cols],
    by = "pixelGroup"
  ) |> na.omit()
  setkey(pixelGroupParameters, pixelGroup)
  setcolorder(pixelGroupParameters, "pixelGroup")
  
  values(pixelGroupMap)[!(values(pixelGroupMap) %in% pixelGroupParameters$pixelGroup)] <- NA
  return(list = list(pixelGroupMap = pixelGroupMap, pixelGroupParameters  = pixelGroupParameters))
}

