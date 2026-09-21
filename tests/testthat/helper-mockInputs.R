# Shared builders for small, fully offline (no-network) mock objects
# satisfying every expectsInput() of BiomeBGC_dataPrep, for use by the
# integration tests (test-5/6-integration-*.R). Auto-sourced by testthat
# via the helper-*.R naming convention.

# A minimal, physically-plausible ecophysiological constants row for a
# single mock species, built from the real fixture .epc file so values are
# realistic rather than arbitrary.
.mockEcophysiologicalConstants <- function(speciesId = "Pice_gla") {
  epc <- epcRead(testthat::test_path("testdata", "epc", "enf.epc"))
  epcRow <- as.list(setNames(epc[["value"]], make.names(epc[["description"]])))
  data.frame(
    speciesId = speciesId,
    species = "Picea glauca",
    genus = "Picea",
    PFT = "enf",
    stringsAsFactors = FALSE
  )
}

# Build a short, structurally valid meteorological time series (daily rows,
# 365 days/year, no Feb 29) for one climate polygon, spanning nSpinupYears
# before firstSimYear through lastSimYear.
.mockMetDataForPolygon <- function(firstSimYear, lastSimYear, nSpinupYears) {
  years <- (firstSimYear - nSpinupYears):lastSimYear
  do.call(rbind, lapply(years, function(yr) {
    data.frame(
      year = yr,
      yday = 1:365,
      tmax = 10 + 5 * sin(2 * pi * (1:365) / 365),
      tmin = 2 + 5 * sin(2 * pi * (1:365) / 365),
      tday = 6 + 5 * sin(2 * pi * (1:365) / 365),
      prcp = 0.2,
      vpd = 300,
      srad = 150,
      daylen = 30000,
      spinup = yr < firstSimYear
    )
  }))
}

# Build a small CO2 concentration series covering firstYear:lastYear.
.mockCO2Concentration <- function(firstYear, lastYear) {
  data.frame(
    year = firstYear:lastYear,
    co2_ppm = 400
  )
}

#' Build mock inputs for a polygon studyArea.
#'
#' Creates a small (4x4 cell) rasterToMatch, with the first two cells set to
#' a different soilDepth than the rest, so LandR::generatePixelGroups()
#' produces more than one pixelGroup.
makeMockPolygonInputs <- function(nrow = 4, ncol = 4, simStart = 2000, simEnd = 2002, metSpinupYears = 5) {
  rasterToMatch <- terra::rast(
    nrows = nrow, ncols = ncol,
    xmin = -1000, xmax = -1000 + ncol * 250,
    ymin = 5900000, ymax = 5900000 + nrow * 250,
    crs = "EPSG:3978"
  )
  terra::values(rasterToMatch) <- 1

  studyArea <- terra::as.polygons(rasterToMatch, extent = TRUE)
  studyArea$studyAreaId <- 1

  dominantSpecies <- terra::rast(rasterToMatch)
  terra::values(dominantSpecies) <- 1L
  levels(dominantSpecies) <- data.frame(id = 1L, category = "Pice_gla")

  climatePolygons <- studyArea
  climatePolygons$climatePolygonId <- 1

  # vary soilDepth over the first 2 cells vs the rest, to force >1 pixelGroup
  soilDepth <- terra::rast(rasterToMatch)
  ncells <- terra::ncell(rasterToMatch)
  terra::values(soilDepth) <- c(rep(0.6, 2), rep(1.2, ncells - 2))

  soilTexture <- c(
    sand = {r <- terra::rast(rasterToMatch); terra::values(r) <- 30; r},
    silt = {r <- terra::rast(rasterToMatch); terra::values(r) <- 50; r},
    clay = {r <- terra::rast(rasterToMatch); terra::values(r) <- 20; r}
  )
  names(soilTexture) <- c("sand", "silt", "clay")

  shortwaveAlbedo <- terra::rast(rasterToMatch); terra::values(shortwaveAlbedo) <- 0.15
  elevation <- terra::rast(rasterToMatch); terra::values(elevation) <- 500
  NfixationRates <- terra::rast(rasterToMatch); terra::values(NfixationRates) <- 0.0001
  snowpackWaterContent <- terra::rast(rasterToMatch); terra::values(snowpackWaterContent) <- 10

  NdepositionT1 <- terra::rast(rasterToMatch); terra::values(NdepositionT1) <- 0.002
  NdepositionT2 <- terra::rast(rasterToMatch); terra::values(NdepositionT2) <- 0.0025
  Ndeposition <- c(NdepositionT1, NdepositionT2)
  names(Ndeposition) <- c("2015", "2020")

  sppEquiv <- .mockEcophysiologicalConstants()
  ecophysiologicalConstants <- data.frame(speciesId = "Pice_gla")

  meteorologicalData <- list(`1` = .mockMetDataForPolygon(simStart, simEnd, metSpinupYears))
  CO2concentration <- .mockCO2Concentration(simStart - metSpinupYears, simEnd)

  list(
    objects = list(
      studyArea = studyArea,
      rasterToMatch = rasterToMatch,
      dominantSpecies = dominantSpecies,
      climatePolygons = climatePolygons,
      sppEquiv = sppEquiv,
      ecophysiologicalConstants = ecophysiologicalConstants,
      soilTexture = soilTexture,
      soilDepth = soilDepth,
      elevation = elevation,
      Ndeposition = Ndeposition,
      NfixationRates = NfixationRates,
      snowpackWaterContent = snowpackWaterContent,
      shortwaveAlbedo = shortwaveAlbedo,
      meteorologicalData = meteorologicalData,
      CO2concentration = CO2concentration
    ),
    times = list(start = simStart, end = simEnd),
    metSpinupYears = metSpinupYears
  )
}

#' Build mock inputs for a point studyArea.
#'
#' Mirrors makeMockPolygonInputs(), but studyArea is a single point and
#' rasterToMatch covers a small area around it (as required by the fixed
#' `res(sim$rasterToMatch)` line in the point branch of .inputObjects()).
makeMockPointInputs <- function(simStart = 2000, simEnd = 2002, metSpinupYears = 5) {
  polygonMocks <- makeMockPolygonInputs(nrow = 2, ncol = 2, simStart = simStart, simEnd = simEnd, metSpinupYears = metSpinupYears)

  rasterToMatch <- polygonMocks$objects$rasterToMatch
  pointCoords <- terra::xyFromCell(rasterToMatch, terra::ncell(rasterToMatch) %/% 2 + 1)
  studyArea <- terra::vect(pointCoords, type = "points", crs = terra::crs(rasterToMatch))
  studyArea$studyAreaId <- 1

  objects <- polygonMocks$objects
  objects$studyArea <- studyArea

  list(
    objects = objects,
    times = polygonMocks$times,
    metSpinupYears = polygonMocks$metSpinupYears
  )
}
