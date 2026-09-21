if (!testthat::is_testing()) {
  source(testthat::test_path("setup.R"))
}

# prepareSpinupIni() unconditionally calls getOutputDescription(), which
# fetches https://raw.githubusercontent.com/bpbond/Biome-BGC/... with no
# suppliedElsewhere() guard (unlike every other module input). These tests
# therefore require network access even though every other input is mocked.
testthat::skip_if_offline()
testthat::skip_if_not_installed("SpaDES.core")

test_that("the module runs end-to-end for a point studyArea with fully mocked inputs", {
  # Avoid library(SpaDES.core): its .onAttach() calls setPaths() and can
  # error in some interactive sessions; requireNamespace()/:: calls sidestep
  # that entirely and are all we need here.
  requireNamespace("SpaDES.core", quietly = TRUE)

  mocks <- makeMockPointInputs()

  parameters <- list(
    BiomeBGC_dataPrep = list(
      maxSpinupYears = 10L,
      metSpinupYears = mocks$metSpinupYears,
      .plots = "none",
      .useCache = FALSE
    )
  )

  sim <- SpaDES.core::simInit(
    times = mocks$times,
    params = parameters,
    modules = list("BiomeBGC_dataPrep"),
    objects = mocks$objects,
    paths = list(
      modulePath = normalizePath(file.path("..", "..", "..")),
      inputPath = tempfile("bbgc-point-input-"),
      outputPath = tempfile("bbgc-point-output-"),
      cachePath = tempfile("bbgc-point-cache-")
    )
  )

  expect_true(inherits(sim$studyArea, "SpatVector"))
  expect_equal(terra::geomtype(sim$studyArea), "points")

  out <- NULL
  # simInit()'s internal Require() package-loading check misparses the
  # named BioSIM = "RNCan/BioSimClient_R" reqdPkgs entry: it derives an
  # expected package name from the GitHub repo name ("BioSimClient_R")
  # instead of the DESCRIPTION Package: field ("BioSIM"), and warns that
  # "BioSimClient_R" could not be installed even though BioSIM (the
  # actually-installed, actually-used package) is present and functional.
  # This is a cosmetic warning from SpaDES.core/Require internals, not a
  # bug in this module, so it is tolerated here while still failing on
  # any other, unexpected warning.
  withCallingHandlers(
    {
      out <- SpaDES.core::spades(sim, debug = FALSE)
    },
    warning = function(w) {
      if (grepl("BioSimClient_R", conditionMessage(w), fixed = TRUE)) {
        invokeRestart("muffleWarning")
      }
    }
  )

  expect_s4_class(out, "simList")

  # exactly one point -> exactly one pixel group
  expect_equal(nrow(out$pixelGroupParameters), 1)
  expect_true(all(
    c(
      "pixelGroup",
      "climatePolygon",
      "dominantSpecies",
      "soilSandContent",
      "soilClayContent",
      "soilSiltContent",
      "soilDepth",
      "soilAlbedo",
      "NdepositionT1",
      "NdepositionT2",
      "NfixationRate",
      "elevation",
      "latitude",
      "snowPackWaterContent"
    ) %in%
      names(out$pixelGroupParameters)
  ))

  expect_type(out$bbgcSpinup.ini, "list")
  expect_length(out$bbgcSpinup.ini, 1)
  expect_type(out$bbgc.ini, "list")
  expect_length(out$bbgc.ini, 1)

  pixelGroupId <- as.character(out$pixelGroupParameters$pixelGroup[1])
  expect_equal(
    BiomeBGCR::iniGet(out$bbgcSpinup.ini[[pixelGroupId]], "EPC_FILE", 1),
    file.path("inputs", "epc", "piceaglauca.epc")
  )
})
