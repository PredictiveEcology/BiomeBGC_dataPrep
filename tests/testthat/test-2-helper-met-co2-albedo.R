if (!testthat::is_testing()) {
  source(testthat::test_path("setup.R"))
}

test_that("metWrite() writes a correctly formatted .mtc43 file", {
  metData <- data.frame(
    year = c(2000, 2000),
    yday = c(1, 2),
    tmax = c(5.5, 6.1),
    tmin = c(-2.3, -1.0),
    tday = c(2.1, 2.8),
    prcp = c(0.1, 0.0),
    vpd = c(300.5, 310.2),
    srad = c(100.2, 110.5),
    daylen = c(28000, 28100)
  )
  outFile <- tempfile(fileext = ".mtc43")
  on.exit(unlink(outFile))

  metWrite(metData, outFile, siteName = "TestSite", dataSource = "unit-test")

  lines <- readLines(outFile)
  # 2 header/source lines + 2 column-name/unit lines + 1 line per data row
  expect_length(lines, 4 + nrow(metData))
  expect_match(lines[1], "^TestSite,2000-2000$")
  expect_match(lines[3], "year[[:space:]]+yday[[:space:]]+Tmax")

  reRead <- metRead(outFile)
  expect_equal(nrow(reRead), nrow(metData))
  expect_equal(reRead[["year"]], metData[["year"]])
  expect_equal(reRead[["tmax"]], metData[["tmax"]], tolerance = 1e-2)
  expect_equal(reRead[["daylen"]], metData[["daylen"]])
})

test_that("CO2write() writes a tab-delimited 2-column file that round-trips", {
  co2Data <- data.frame(
    year = 2000:2002,
    concentration = c(370.1, 371.5, 372.9)
  )
  outFile <- tempfile(fileext = ".txt")
  on.exit(unlink(outFile))

  CO2write(co2Data, outFile)

  reRead <- read.table(
    outFile,
    col.names = c("year", "concentration"),
    sep = "\t"
  )
  expect_equal(reRead[["year"]], co2Data[["year"]])
  expect_equal(
    reRead[["concentration"]],
    co2Data[["concentration"]],
    tolerance = 1e-6
  )
})

test_that("lccToAlbedo() looks up albedo values by land-cover class and latitude band", {
  skip_if_not_installed("terra")
  library(terra)

  lcc <- rast(
    nrows = 1,
    ncols = 4,
    xmin = -100,
    xmax = -96,
    ymin = 45,
    ymax = 46,
    crs = "EPSG:4326"
  )
  values(lcc) <- c(2, 4, 5, 6) # herbs, shrub, treed broadleaf, treed conifer

  # albedoTable: rows = lookup rows used by lccToAlbedo (1=conifer,3=broadleaf,5=shrub,7=herb),
  # cols = latitude bands (col 4 here, since latitude ~45.5 falls in the ">40, <=50" band)
  albedoTable <- matrix(NA_real_, nrow = 7, ncol = 5)
  albedoTable[7, 4] <- 0.20 # herbs
  albedoTable[5, 4] <- 0.15 # shrub
  albedoTable[3, 4] <- 0.10 # treed broadleaf
  albedoTable[1, 4] <- 0.05 # treed conifer

  out <- lccToAlbedo(lcc, albedoTable, rasterToMatch = lcc)

  expect_s4_class(out, "SpatRaster")
  vals <- values(out, drop = TRUE)
  expect_equal(as.numeric(vals), c(0.20, 0.15, 0.10, 0.05), tolerance = 1e-8)
})

test_that("lccToAlbedo() falls back to 0.1 for unmapped land-cover classes", {
  skip_if_not_installed("terra")
  library(terra)

  lcc <- rast(
    nrows = 1,
    ncols = 1,
    xmin = -100,
    xmax = -99,
    ymin = 45,
    ymax = 46,
    crs = "EPSG:4326"
  )
  values(lcc) <- 99 # not a recognized NFI class

  albedoTable <- matrix(0.5, nrow = 7, ncol = 5)
  out <- lccToAlbedo(lcc, albedoTable, rasterToMatch = lcc)

  expect_equal(values(out, drop = TRUE)[1], 0.1)
})

test_that("fillMissingValues() fills NA cells with a focal mean", {
  # Note: `treedPixels` only controls whether/how much filling is attempted
  # (the while() loop and growing window size); terra::focal(na.policy = "only")
  # itself fills every reachable NA cell in the raster, treed or not.
  skip_if_not_installed("terra")
  library(terra)

  r <- rast(
    nrows = 3,
    ncols = 3,
    xmin = 0,
    xmax = 3,
    ymin = 0,
    ymax = 3,
    crs = "EPSG:4326"
  )
  vals <- c(1, 2, 3, 4, NA, 6, 7, 8, NA)
  values(r) <- vals
  treed <- c(TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE) # only cell 5 must be resolved

  filled <- fillMissingValues(r, treedPixels = treed, inputName = "test raster")

  filledVals <- values(filled, drop = TRUE)
  expect_false(anyNA(filledVals))
  # values outside the filled cells are unchanged
  expect_equal(filledVals[c(1, 2, 3, 4, 6, 7, 8)], vals[c(1, 2, 3, 4, 6, 7, 8)])
})

test_that("fillMissingValues() is a no-op when there are no NAs in the treed mask", {
  skip_if_not_installed("terra")
  library(terra)

  r <- rast(
    nrows = 2,
    ncols = 2,
    xmin = 0,
    xmax = 2,
    ymin = 0,
    ymax = 2,
    crs = "EPSG:4326"
  )
  values(r) <- c(1, 2, 3, 4)
  treed <- c(TRUE, TRUE, TRUE, TRUE)

  out <- fillMissingValues(r, treedPixels = treed, inputName = "no-op raster")
  expect_equal(as.numeric(values(out, drop = TRUE)), c(1, 2, 3, 4))
})
