if (!testthat::is_testing()) {
  suppressPackageStartupMessages(library(testthat))
  testthat::source_test_helpers(env = globalenv())
}

# Source the module's helper/prep functions directly, so we can unit test
# them without a full simInit()/spades() run (which requires network access
# for climate, soils, and species data -- see tests/README.md).
suppressPackageStartupMessages({
  library(data.table)
  library(terra)
})

# BioSIM (RNCan/BioSimClient_R) imports J4R (CWFC-CCFB/J4R), which is
# GitHub-only (not on CRAN); LandR in turn Suggests BioSIM. All of these are
# installed together in one Require::Require() batch call by the reusable CI
# workflow, and pak's parallel "identify-and-defer" install strategy can
# attempt to build a package before its GitHub-only dependency has finished
# installing. When that happens, the dependent package -- and anything that
# in turn depends on it (LandR, then pemisc) -- is left missing even though
# J4R itself lands successfully (see PredictiveEcology/BiomeBGC_dataPrep#7).
# remotes installs serially and follows a package's Remotes: DESCRIPTION
# field, so retry with it here, in dependency order, for whatever the batch
# install left missing.
if (!requireNamespace("J4R", quietly = TRUE) || !requireNamespace("BioSIM", quietly = TRUE) ||
    !requireNamespace("LandR", quietly = TRUE) || !requireNamespace("pemisc", quietly = TRUE)) {
  if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")
  if (!requireNamespace("J4R", quietly = TRUE)) remotes::install_github("CWFC-CCFB/J4R")
  if (!requireNamespace("BioSIM", quietly = TRUE)) remotes::install_github("RNCan/BioSimClient_R")
  if (!requireNamespace("pemisc", quietly = TRUE)) remotes::install_github("PredictiveEcology/pemisc@development")
  if (!requireNamespace("LandR", quietly = TRUE)) remotes::install_github("PredictiveEcology/LandR@development")
}

moduleRPath <- testthat::test_path("..", "..", "R")
lapply(list.files(moduleRPath, pattern = "[.]R$", full.names = TRUE), source)

# Convenience path to the fixture files copied from BiomeBGCR/inst/inputs/
testdataPath <- testthat::test_path("testdata")
