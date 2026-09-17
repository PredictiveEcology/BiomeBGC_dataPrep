# Tests for BiomeBGC_dataPrep

This suite unit-tests the pure/file-based functions in `R/helper.R` and
`R/prepIniFncts.R`, using small fixture files copied from
`BiomeBGCR/inst/inputs/` (`ini/template.ini`, `epc/enf.epc`, a truncated
`co2/co2_small.txt`, and a truncated `metdata/oth_small.mtc43`).

## What's covered

- `R/helper.R`: EPC read/parse/write, EPC proportion cleanup, MET/CO2
  read-write round trips, land-cover-to-albedo lookup, and the focal-mean
  gap-filling helper.
- `R/prepIniFncts.R`: building per-pixel-group spinup `.ini` files, including
  the fallback logic between `pixelGroupParameters` and user-supplied
  `siteConstants`/`NDeposition`/`waterState` overrides.
- A smoke test that the module's `defineModule()` metadata parses and that
  all functions referenced by module events/helpers exist.

## What's out of scope (for now)

`R/prepInputFncts.R`'s network-dependent functions are now covered by
`test-7-prepInputFncts-network.R` (see below) rather than being entirely
out of scope, but full end-to-end runs are only exercised for the functions
whose downloads are small (KB-scale, or a single small elevation tile).

## Integration tests (`test-5`/`test-6`)

`test-5-integration-point.R` and `test-6-integration-polygon.R` run the full
module (`simInit()` + `spades()`) once for a point `studyArea` and once for
a polygon `studyArea`, using small, fully synthetic mock objects (built in
`helper-mockInputs.R`) for every `expectsInput`, so no NTEMS/CanSIS/ORNL/
BioSIM/Google-Drive downloads happen. Both tests call
`testthat::skip_if_offline()` because `prepareSpinupIni()` unconditionally
calls `getOutputDescription()`, which fetches a lookup table from GitHub
with no `suppliedElsewhere()` guard — this is a known limitation, not
something these tests work around, so the tests still require network
access and will skip cleanly without it.

While building these tests, two source bugs were found and fixed in
`BiomeBGC_dataPrep.R`:
- The point-`studyArea` branch of `.inputObjects()` referenced
  `sim$rastertoMatch` (typo) instead of `sim$rasterToMatch`.
- `expectsInput("NFixationRates", ...)` and its `suppliedElsewhere()` guard
  used the wrong case; the object is consumed everywhere else as
  `sim$NfixationRates` (lowercase f). The declaration/guard was renamed to
  match.

## Network tests for `R/prepInputFncts.R` (`test-7`)

`test-7-prepInputFncts-network.R` tests the functions in
`R/prepInputFncts.R` that hit the network, all guarded by
`testthat::skip_if_offline()`:

- **Run end-to-end** (small downloads: KB-scale files, or a single small
  elevation tile for a tiny extent): `prepCo2Concentration()`,
  `rvestAlbedoTable()`, `prepElevation()`, `prepEPC()`.
- **Reachability + signature checks only** (would otherwise download
  multi-GB national rasters via `prepInputs()`, which fetches the whole
  file before cropping — e.g. one CanSIS sand layer alone is ~3.2 GB):
  `prepNTEMSDominantSpecies()`, `prepSoilTexture()`, `prepNdeposition()`,
  `prepSoilDepth()`, `prepNfixation()`, `prepSnowpackWaterContent()`. These
  tests send a `HEAD` request to the source URL (or, for Google-Drive-hosted
  sources without a meaningful HEAD check, just confirm the function's
  signature) rather than exercising the full `prepInputs()`/`Cache()`
  pipeline against real data.
- `prepClimate()`/`prepClimateSinglePolygon()` require `BioSimClient_R` (a
  live BioSIM server session) and are only smoke-tested (signature check)
  when that package is installed; skipped otherwise via
  `skip_if_not_installed("BioSimClient_R")`.

## Running

```r
testthat::test_dir(file.path("tests", "testthat"))
```

or see `tests/testthat/devel-runTests.R` for running individual files.

---
Drafted with assistance from Claude (Posit Assistant).
