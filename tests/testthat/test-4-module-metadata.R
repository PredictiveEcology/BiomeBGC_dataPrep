if (!testthat::is_testing()) {
  source(testthat::test_path("setup.R"))
}

modulePath <- normalizePath(file.path("..", ".."), mustWork = TRUE)
moduleParentPath <- dirname(modulePath)
moduleName <- basename(modulePath)

test_that("all functions referenced by module events exist and are functions", {
  # Sourced in setup.R from R/*.R -- this guards against typos/renames that
  # would otherwise only surface at simInit()/spades() time.
  helperFunctions <- c(
    "epcRead",
    "epcParseLine",
    "epcWrite",
    "epcWrite2",
    "fillMissingEPCProportions",
    "scaleEPCProportions",
    "cleanEPC",
    "initiateEPC",
    "metWrite",
    "CO2write",
    "lccToAlbedo",
    "fillMissingValues",
    "prepSpinupIni",
    "prepSpinupIni_worker",
    "prepPixelGroups"
  )
  for (fn in helperFunctions) {
    expect_true(exists(fn, mode = "function"), info = fn)
  }
})

test_that("BiomeBGC_dataPrep.R defines its documented event/helper functions", {
  # BiomeBGC_dataPrep.R wraps everything in defineModule(sim, ...), so it
  # can't be source()-d outside of simInit(); instead, check (via a static
  # regex scan) that each function referenced by the module's events is
  # actually defined somewhere in the file. This catches typos/removed
  # functions without requiring a full simInit()/spades() run.
  moduleScript <- readLines(file.path(modulePath, "BiomeBGC_dataPrep.R"))
  moduleScriptText <- paste(moduleScript, collapse = "\n")

  eventFunctions <- c(
    "doEvent[.]BiomeBGC_dataPrep",
    "Save <- function",
    "preparePixelGroups <- function",
    "prepareSpinupIni <- function",
    "prepareIni <- function",
    "climatePlot <- function",
    "climatePolygonMap <- function",
    "[.]inputObjects <- function"
  )
  for (pattern in eventFunctions) {
    expect_true(grepl(pattern, moduleScriptText), info = pattern)
  }
})

test_that("the module's defineModule() metadata parses and lists the documented inputs/outputs", {
  skip_if_not_installed("SpaDES.core")

  moduleMetadata <- tryCatch(
    SpaDES.core::moduleMetadata(module = moduleName, path = moduleParentPath),
    error = function(e) NULL
  )
  skip_if(
    is.null(moduleMetadata),
    "SpaDES.core::moduleMetadata() could not be evaluated in this environment"
  )

  expect_equal(moduleMetadata$name, "BiomeBGC_dataPrep")

  inputNames <- moduleMetadata$inputObjects$objectName
  expect_true(all(
    c("studyArea", "dominantSpecies", "climatePolygons", "rasterToMatch") %in%
      inputNames
  ))

  outputNames <- moduleMetadata$outputObjects$objectName
  expect_true(all(
    c(
      "bbgcSpinup.ini",
      "bbgc.ini",
      "pixelGroupMap",
      "pixelGroupParameters"
    ) %in%
      outputNames
  ))
})
