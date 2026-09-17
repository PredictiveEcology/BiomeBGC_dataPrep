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

moduleRPath <- testthat::test_path("..", "..", "R")
lapply(list.files(moduleRPath, pattern = "[.]R$", full.names = TRUE), source)

# Convenience path to the fixture files copied from BiomeBGCR/inst/inputs/
testdataPath <- testthat::test_path("testdata")
