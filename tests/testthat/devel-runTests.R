## Not itself a test file (does not match the test-*.R pattern), so it is not
## auto-discovered by testthat::test_dir(). Use these lines interactively.

## RUN ALL TESTS ----
testthat::test_dir(file.path("tests", "testthat"))
testthat::test_dir(file.path("tests", "testthat"), reporter = testthat::SummaryReporter)

## RUN INDIVIDUAL TEST FILES ----
testthat::test_file(file.path("tests", "testthat", "test-1-helper-epc.R"))
testthat::test_file(file.path("tests", "testthat", "test-2-helper-met-co2-albedo.R"))
testthat::test_file(file.path("tests", "testthat", "test-3-prepIniFncts.R"))
testthat::test_file(file.path("tests", "testthat", "test-4-module-metadata.R"))
