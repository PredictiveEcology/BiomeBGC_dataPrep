if (!testthat::is_testing()) source(testthat::test_path("setup.R"))

# All tests here rely on BiomeBGCR::iniRead()/iniGet()/iniSet() to read and
# query .ini structures -- these are exported by the companion BiomeBGCR
# package this module depends on.
skip_if_not_installed("BiomeBGCR")
library(BiomeBGCR)

iniTemplatePath <- file.path(testdataPath, "ini", "template.ini")

makePixelGroupParameters <- function() {
  data.table::data.table(
    pixelGroup = c(1, 2),
    climatePolygon = c("polyA", "polyB"),
    dominantSpecies = c("Pice_gla", "Pinu_ban"),
    soilSandContent = c(30, 40),
    soilSiltContent = c(50, 40),
    soilClayContent = c(20, 20),
    soilDepth = c(1.2, 0.8),
    soilAlbedo = c(0.15, 0.18),
    NdepositionT1 = c(0.002, 0.003),
    NdepositionT2 = c(0.0025, 0.0035),
    NfixationRate = c(0.0001, 0.0002),
    elevation = c(500, 700),
    latitude = c(53.5, 54.2),
    snowPackWaterContent = c(10, 15)
  )
}

speciesLookup <- c(Pice_gla = "picea_glauca", Pinu_ban = "pinus_banksiana")

test_that("prepSpinupIni_worker() fills SITE/MET_INPUT/EPC_FILE from pixelGroupParameters when userParams are NA", {
  iniTemplate <- iniRead(iniTemplatePath)
  pixelGroupParameters <- makePixelGroupParameters()
  userParams <- list(
    siteConstants = rep(NA_real_, 9),
    NDeposition = c(0, NA),
    waterState = NA_real_
  )

  ini1 <- prepSpinupIni_worker(
    pixelGroup_i = 1,
    iniTemplate = iniTemplate,
    pixelGroupParameters = pixelGroupParameters,
    restartPath = file.path("inputs", "restart"),
    userParams = userParams,
    species_lookup = speciesLookup,
    Ndep_yr2 = 2050
  )

  expect_equal(iniGet(ini1, "SITE", 1), "1.2")     # soil depth from pixelGroupParameters
  expect_equal(iniGet(ini1, "SITE", 5), "500")     # elevation
  expect_equal(iniGet(ini1, "MET_INPUT", 1), file.path("inputs", "metdata", "polyA_spinup.mtc43"))
  expect_equal(iniGet(ini1, "EPC_FILE", 1), file.path("inputs", "epc", "picea_glauca.epc"))
  expect_equal(iniGet(ini1, "RESTART", 5), file.path("inputs", "restart", "1.restart"))
})

test_that("prepSpinupIni_worker() prefers non-NA userParams over pixelGroupParameters", {
  iniTemplate <- iniRead(iniTemplatePath)
  pixelGroupParameters <- makePixelGroupParameters()
  userParams <- list(
    siteConstants = c(2.0, NA, NA, NA, 999, NA, NA, NA, NA),
    NDeposition = c(0, NA),
    waterState = 5
  )

  ini1 <- prepSpinupIni_worker(
    pixelGroup_i = 1,
    iniTemplate = iniTemplate,
    pixelGroupParameters = pixelGroupParameters,
    restartPath = file.path("inputs", "restart"),
    userParams = userParams,
    species_lookup = speciesLookup,
    Ndep_yr2 = 2050
  )

  # overridden values
  expect_equal(iniGet(ini1, "SITE", 1), "2")
  expect_equal(iniGet(ini1, "SITE", 5), "999")
  expect_equal(iniGet(ini1, "W_STATE", 1), "5")
  # still falls back to pixelGroupParameters for the non-overridden soil texture (index 2)
  expect_equal(iniGet(ini1, "SITE", 2), "30")
})

test_that("prepSpinupIni() builds one named ini per pixel group", {
  iniTemplate <- iniRead(iniTemplatePath)
  pixelGroupParameters <- makePixelGroupParameters()
  userParams <- list(
    siteConstants = rep(NA_real_, 9),
    NDeposition = c(0, NA),
    waterState = NA_real_
  )

  allIni <- prepSpinupIni(pixelGroupParameters, iniTemplate, userParams, speciesLookup, Ndep_yr2 = 2050)

  expect_type(allIni, "list")
  expect_length(allIni, nrow(pixelGroupParameters))
  expect_equal(names(allIni), as.character(pixelGroupParameters$pixelGroup))
  expect_equal(
    iniGet(allIni[["2"]], "MET_INPUT", 1),
    file.path("inputs", "metdata", "polyB_spinup.mtc43")
  )
  expect_equal(
    iniGet(allIni[["2"]], "EPC_FILE", 1),
    file.path("inputs", "epc", "pinus_banksiana.epc")
  )
})
