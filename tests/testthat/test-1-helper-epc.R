if (!testthat::is_testing()) {
  source(testthat::test_path("setup.R"))
}

test_that("epcRead() parses a fixture .epc file into a well-formed data.frame", {
  epc <- epcRead(file.path(testdataPath, "epc", "enf.epc"))

  expect_s3_class(epc, "data.frame")
  expect_named(epc, c("description", "unit", "value"))
  expect_type(epc[["value"]], "double")
  expect_type(epc[["description"]], "character")
  expect_type(epc[["unit"]], "character")
  expect_true(nrow(epc) > 0)
  expect_false(anyNA(epc[["value"]]))

  # attributes carry the functional-type description parsed from the header
  expect_equal(attr(epc, "title"), "ECOPHYS")
  expect_true(nzchar(attr(epc, "description")))
})

test_that("epcRead() readValues/readMeta toggles change the returned shape", {
  valuesOnly <- epcRead(
    file.path(testdataPath, "epc", "enf.epc"),
    readValues = TRUE,
    readMeta = FALSE
  )
  metaOnly <- epcRead(
    file.path(testdataPath, "epc", "enf.epc"),
    readValues = FALSE,
    readMeta = TRUE
  )

  expect_type(valuesOnly, "double")
  expect_s3_class(metaOnly, "data.frame")
  expect_named(metaOnly, c("description", "unit"))

  expect_warning(
    empty <- epcRead(
      file.path(testdataPath, "epc", "enf.epc"),
      readValues = FALSE,
      readMeta = FALSE
    ),
    "readValues and readMeta are FALSE"
  )
  expect_null(empty)
})

test_that("epcParseLine() splits a data line into description/unit/value", {
  parsed <- epcParseLine(
    "0.25          (1/yr)    annual leaf and fine root turnover fraction"
  )

  expect_length(parsed, 3)
  expect_equal(parsed[2], "1/yr")
  expect_equal(parsed[3], "0.25")
  expect_match(parsed[1], "annual leaf and fine root turnover fraction")
})

test_that("epcParseLine() splits flag lines' description on '0'/'1' wording", {
  parsed <- epcParseLine(
    "1             (flag)    1 = WOODY             0 = NON-WOODY"
  )

  expect_equal(parsed[2], "flag")
  expect_equal(parsed[3], "1")
  # a "; " separator should have been inserted before the "0 = " part
  expect_match(parsed[1], "; 0")
})

test_that("initiateEPC() returns an empty data.frame with the expected schema", {
  epc <- initiateEPC()

  expect_s3_class(epc, "data.frame")
  expect_equal(nrow(epc), 0)
  expect_equal(ncol(epc), 45)
  expect_true(all(
    c("taxa", "level", "leafAndFineRootTurnover", "CtoNLeaves") %in% names(epc)
  ))
  expect_type(epc[["woody"]], "integer")
  expect_type(epc[["leafAndFineRootTurnover"]], "double")
  expect_s3_class(epc[["level"]], "factor")
  expect_equal(levels(epc[["level"]]), c("species", "genus", "pft"))
})

test_that("epcWrite() and epcRead() round-trip a data.frame through a file", {
  epc <- epcRead(file.path(testdataPath, "epc", "enf.epc"))
  outFile <- tempfile(fileext = ".epc")
  on.exit(unlink(outFile))

  epcWrite(epc, fileName = outFile)
  expect_true(file.exists(outFile))

  reRead <- epcRead(outFile)
  expect_equal(nrow(reRead), nrow(epc))
  # values should be preserved (write() rounds to 5 decimals)
  expect_equal(reRead[["value"]], round(epc[["value"]], 5), tolerance = 1e-5)
})

test_that("fillMissingEPCProportions() infers the one missing proportion in a triplet", {
  epc <- data.table(
    fineRootLabileProportion = c(0.3, 0.2, NA),
    fineRootCelluloseProportion = c(0.5, NA, 0.4),
    fineRootLigninProportion = c(NA, 0.3, 0.3)
  )

  filled <- fillMissingEPCProportions(copy(epc), pools = "fineRoot")

  expect_false(anyNA(filled))
  expect_equal(filled[["fineRootLigninProportion"]][1], 0.3, tolerance = 1e-8)
  expect_equal(
    filled[["fineRootCelluloseProportion"]][2],
    0.5,
    tolerance = 1e-8
  )
  expect_equal(filled[["fineRootLabileProportion"]][3], 0.2, tolerance = 1e-8)
})

test_that("scaleEPCProportions() rescales complete-but-non-normalized triplets to sum to 1", {
  epc <- data.table(
    fineRootLabileProportion = c(0.3, 1),
    fineRootCelluloseProportion = c(0.5, 1),
    fineRootLigninProportion = c(0.4, 1)
  )

  scaled <- scaleEPCProportions(copy(epc), pools = "fineRoot")
  cols <- grep("fineRoot.*Proportion", names(scaled))

  sums <- rowSums(scaled[, ..cols])
  expect_equal(sums, c(1, 1), tolerance = 1e-8)
})
