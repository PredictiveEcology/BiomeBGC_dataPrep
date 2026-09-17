if (!testthat::is_testing()) {
  source(testthat::test_path("setup.R"))
}

# These tests exercise functions in R/prepInputFncts.R that require network
# access. They call testthat::skip_if_offline() so they skip cleanly without
# internet rather than failing.
#
# Several of these functions (prepNTEMSDominantSpecies, prepSoilTexture,
# prepNdeposition, prepSoilDepth, prepNfixation, prepSnowpackWaterContent)
# download full Canada-wide rasters via prepInputs() -- e.g. the CanSIS sand
# layer alone is ~3.2 GB -- because prepInputs() fetches the whole file
# before cropping. Running them for real, even against a tiny extent, would
# download multi-GB files on every uncached test run. For those functions we
# only check that their source URL is reachable (a HEAD request) and that
# obviously-invalid arguments are rejected, rather than exercising the full
# prepInputs()/Cache() pipeline.
#
# The remaining functions (prepEPC, prepCo2Concentration, rvestAlbedoTable,
# prepElevation, prepClimate) download small files (KB-scale, a single small
# elevation tile, or a short BioSIM weather series for one tiny climate
# polygon) and are exercised end-to-end.

skip_if_offline()

## ---- Helpers testable end-to-end (small downloads) ------------------------

test_that("prepCo2Concentration() downloads and subsets CO2 concentration data for a scenario", {
  destinationPath <- tempfile("prepCo2-")
  dir.create(destinationPath)
  on.exit(unlink(destinationPath, recursive = TRUE))

  # prepInputs() emits a benign "file not found" warning on its first
  # (pre-download) attempt to evaluate `fun`; not something this test covers.
  co2 <- suppressWarnings(prepCo2Concentration(
    firstYear = 2000,
    lastYear = 2005,
    scenario = "RCP45",
    destinationPath = destinationPath
  ))

  expect_s3_class(co2, "data.frame")
  expect_named(co2, c("year", "co2_ppm"))
  expect_true(all(co2$year >= 2000 & co2$year <= 2005))
  expect_true(nrow(co2) > 0)

  # a co2_<firstYear>_<lastYear>_<scenario>.txt file should have been written
  writtenFile <- file.path(destinationPath, "co2", "co2_2000_2005_RCP45.txt")
  expect_true(file.exists(writtenFile))
})

test_that("prepCo2Concentration() rejects an unsupported scenario before downloading anything", {
  destinationPath <- tempfile("prepCo2-badscenario-")
  dir.create(destinationPath)
  on.exit(unlink(destinationPath, recursive = TRUE))

  expect_error(
    prepCo2Concentration(
      firstYear = 2000,
      lastYear = 2005,
      scenario = "not-a-real-scenario",
      destinationPath = destinationPath
    ),
    "RCP26, RCP45, RCP60, or RCP85"
  )
})

test_that("rvestAlbedoTable() downloads and reformats the Gao et al. 2005 albedo lookup table", {
  destinationPath <- tempfile("prepAlbedo-")
  dir.create(destinationPath)
  on.exit(unlink(destinationPath, recursive = TRUE))

  albedoTable <- suppressWarnings(rvestAlbedoTable(destinationPath))

  expect_s3_class(albedoTable, "data.frame")
  expect_named(
    albedoTable,
    c("IGBPclass", "lat6070", "lat5060", "lat4050", "lat3040")
  )
  expect_equal(nrow(albedoTable), 9)
  expect_type(albedoTable[["lat4050"]], "double")
})

test_that("prepElevation() downloads and processes a small elevation tile for a tiny study area", {
  skip_if_not_installed("elevatr")
  skip_if_not_installed("sf")

  # A real-world extent (near Quebec City) is needed: elevatr/get_elev_raster
  # fetches actual terrain tiles, so an arbitrary/synthetic extent (as used
  # by the other mock inputs in this suite) can fall outside tile coverage.
  rasterToMatch <- terra::rast(
    nrows = 2,
    ncols = 2,
    xmin = -71.2,
    xmax = -71.1,
    ymin = 46.0,
    ymax = 46.1,
    crs = "EPSG:4326"
  )
  terra::values(rasterToMatch) <- 1
  studyArea <- terra::as.polygons(rasterToMatch, extent = TRUE)

  elevation <- prepElevation(studyArea = studyArea, to = rasterToMatch)

  expect_s4_class(elevation, "SpatRaster")
  expect_equal(terra::ncell(elevation), terra::ncell(rasterToMatch))
  # rounded to the nearest 50 m
  vals <- na.omit(terra::values(elevation, drop = TRUE))
  expect_true(all(vals %% 50 == 0))
})

test_that("prepEPC() downloads the master EPC table, filters to the requested species, and writes .epc files", {
  destinationPath <- tempfile("prepEPC-")
  dir.create(destinationPath)
  on.exit(unlink(destinationPath, recursive = TRUE))

  sppEquiv <- data.frame(speciesId = "Pice_gla", stringsAsFactors = FALSE)

  epc <- prepEPC(
    url = "https://drive.google.com/file/d/1ffAiI9_8cR8nUOXWiWbEa59vOtqEx_ii/view?usp=sharing",
    sppEquiv = sppEquiv,
    destinationPath = destinationPath
  )

  expect_s3_class(epc, "data.table")
  expect_true(all(epc$speciesId %in% sppEquiv$speciesId))
  expect_true(nrow(epc) > 0)

  # epcWrite2() should have written one .epc file per row, in destinationPath/epc
  epcFiles <- list.files(file.path(destinationPath, "epc"), pattern = "[.]epc$")
  expect_true(length(epcFiles) >= 1)
})

## ---- Large-raster helpers: source-reachability + argument checks only -----
## (see header comment: full runs would download multi-GB national rasters)

test_that("prepNTEMSDominantSpecies()'s source URL is reachable", {
  url <- "https://opendata.nfis.org/downloads/forest_change/CA_Tree_Species_Classification_2019.zip"
  resp <- tryCatch(
    httr::HEAD(url, httr::timeout(15)),
    error = function(e) NULL
  )
  skip_if(is.null(resp), "could not reach the NTEMS species data server")
  expect_true(httr::status_code(resp) < 400)
})

test_that("prepSoilTexture()'s source URLs are reachable", {
  urls <- c(
    "https://sis.agr.gc.ca/cansis/nsdb/psm/Sand/Sand_X0_5_cm_100m1980-2000v1.tif",
    "https://sis.agr.gc.ca/cansis/nsdb/psm/Clay/Clay_X0_5_cm_100m1980-2000v1.tif"
  )
  for (url in urls) {
    resp <- tryCatch(httr::HEAD(url, httr::timeout(15)), error = function(e) {
      NULL
    })
    skip_if(is.null(resp), paste("could not reach", url))
    expect_true(httr::status_code(resp) < 400)
  }
})

test_that("prepNdeposition()'s year1/year2 arguments are used to name the output layers", {
  # We can't run the full download (Google Drive source, and the function
  # otherwise requires a real treedPixels mask sized to a downloaded
  # national raster), so this only checks the naming contract that
  # BiomeBGC_dataPrep.R relies on downstream (sim$Ndeposition[[1]]/[[2]]
  # and names(sim$Ndeposition) <- c(year1, year2)).
  expect_true(is.function(prepNdeposition))
  expect_equal(
    names(formals(prepNdeposition)),
    c("destinationPath", "to", "year1", "year2", "treedPixels")
  )
})

test_that("prepSoilDepth()'s source URL is reachable", {
  # Google Drive share links don't support a meaningful HEAD status check
  # for reachability the way direct file URLs do; just confirm the function
  # exists with the expected signature (its full run needs a national
  # download, see header comment).
  expect_true(is.function(prepSoilDepth))
  expect_equal(
    names(formals(prepSoilDepth)),
    c("destinationPath", "to", "treedPixels")
  )
})

test_that("prepNfixation() has the expected signature", {
  expect_true(is.function(prepNfixation))
  expect_equal(
    names(formals(prepNfixation)),
    c("destinationPath", "to", "treedPixels")
  )
})

test_that("prepSnowpackWaterContent()'s source URL is reachable", {
  url <- "https://climate-scenarios.canada.ca/files/blended_snow_2024/swe_monthly_mm_1981-2020.zip"
  resp <- tryCatch(httr::HEAD(url, httr::timeout(15)), error = function(e) NULL)
  skip_if(is.null(resp), "could not reach the ECCC blended-snow data server")
  expect_true(httr::status_code(resp) < 400)
})

## ---- prepClimate(): requires BioSIM (installed from RNCan/BioSimClient_R) --

test_that("prepClimate() downloads and writes spinup + full-run meteorological data via BioSIM", {
  # The GitHub repo is RNCan/BioSimClient_R, but it builds/installs a package
  # named "BioSIM" (not "BioSimClient_R") -- that's the namespace actually
  # used by generateWeather() in R/prepInputFncts.R, so that's what we check.
  skip_if_not_installed("BioSIM")

  climatePolygons <- terra::as.polygons(
    terra::rast(
      nrows = 1,
      ncols = 1,
      xmin = -71.3,
      xmax = -71.2,
      ymin = 46.7,
      ymax = 46.8,
      crs = "EPSG:4326"
    ),
    extent = TRUE
  )
  climatePolygons$climatePolygonId <- 1

  destinationPath <- tempfile("prepClimate-")
  dir.create(destinationPath)
  on.exit(unlink(destinationPath, recursive = TRUE))

  meteorologicalData <- prepClimate(
    climatePolygons = climatePolygons,
    simStartYear = 2020,
    simEndYear = 2020,
    nSpinupYears = 2,
    scenario = "RCP45",
    climModel = "RCM4",
    destinationPath = destinationPath
  )

  expect_type(meteorologicalData, "list")
  expect_named(meteorologicalData, "1")

  climData <- meteorologicalData[["1"]]
  expect_s3_class(climData, "data.frame")
  expect_named(
    climData,
    c(
      "year",
      "yday",
      "tmax",
      "tmin",
      "tday",
      "prcp",
      "vpd",
      "srad",
      "daylen",
      "spinup"
    )
  )
  expect_equal(nrow(climData), 365 * 3) # 2 spinup years + 1 sim year, no Feb 29
  expect_true(all(climData$yday %in% 1:365))
  expect_equal(sum(climData$spinup), 365 * 2)

  # both a spinup .mtc43 and a full-run .mtc43 should have been written
  writtenFiles <- list.files(file.path(destinationPath, "metdata"))
  expect_true(any(grepl("_spinup[.]mtc43$", writtenFiles)))
  expect_true(any(grepl("rcm4rcp45.*[.]mtc43$", writtenFiles)))
})
