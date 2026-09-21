if (!testthat::is_testing()) {
  source(testthat::test_path("setup.R"))
}

# See test-5-integration-point.R for why these tests require network access
# (prepareSpinupIni() unconditionally calls getOutputDescription()).
testthat::skip_if_offline()
testthat::skip_if_not_installed("SpaDES.core")

test_that("the module runs end-to-end for a polygon studyArea with fully mocked inputs", {
  # See test-5-integration-point.R for why we avoid library(SpaDES.core).
  requireNamespace("SpaDES.core", quietly = TRUE)

  mocks <- makeMockPolygonInputs()

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
      inputPath = tempfile("bbgc-polygon-input-"),
      outputPath = tempfile("bbgc-polygon-output-"),
      cachePath = tempfile("bbgc-polygon-cache-")
    )
  )

  expect_true(inherits(sim$studyArea, "SpatVector"))
  expect_equal(terra::geomtype(sim$studyArea), "polygons")

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

  # the mock varies soilDepth across cells, so more than one pixelGroup is expected
  expect_gt(nrow(out$pixelGroupParameters), 1)
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

  expect_s4_class(out$pixelGroupMap, "SpatRaster")

  # every non-NA cell in pixelGroupMap must have a matching row in pixelGroupParameters
  mapVals <- na.omit(terra::values(out$pixelGroupMap, drop = TRUE))
  expect_true(all(
    unique(as.vector(mapVals)) %in% out$pixelGroupParameters$pixelGroup
  ))

  expect_type(out$bbgcSpinup.ini, "list")
  expect_length(out$bbgcSpinup.ini, nrow(out$pixelGroupParameters))
  expect_type(out$bbgc.ini, "list")
  expect_length(out$bbgc.ini, nrow(out$pixelGroupParameters))
  expect_setequal(
    names(out$bbgcSpinup.ini),
    as.character(out$pixelGroupParameters$pixelGroup)
  )
})
