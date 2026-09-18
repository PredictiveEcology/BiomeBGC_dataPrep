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
# GitHub-only (not on CRAN). The reusable CI workflow installs all of
# reqdPkgs in one Require::Require() batch call, and pak's parallel
# "identify-and-defer" install strategy can attempt to build BioSIM before
# J4R has finished installing, leaving BioSIM missing even though J4R lands
# successfully (see PredictiveEcology/BiomeBGC_dataPrep#7). remotes
# installs serially and follows a package's Remotes: DESCRIPTION field, so
# retry with it here if the batch install left BioSIM (or J4R) missing.
if (!requireNamespace("BioSIM", quietly = TRUE) || !requireNamespace("J4R", quietly = TRUE)) {
  if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")
  if (!requireNamespace("J4R", quietly = TRUE)) remotes::install_github("CWFC-CCFB/J4R")
  if (!requireNamespace("BioSIM", quietly = TRUE)) remotes::install_github("RNCan/BioSimClient_R")
}

moduleRPath <- testthat::test_path("..", "..", "R")
lapply(list.files(moduleRPath, pattern = "[.]R$", full.names = TRUE), source)

# Convenience path to the fixture files copied from BiomeBGCR/inst/inputs/
testdataPath <- testthat::test_path("testdata")
