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

`R/prepInputFncts.R` (`prepNTEMSDominantSpecies`, `prepSoilTexture`,
`prepNdeposition`, `prepClimate`, `prepEPC`, etc.) and the module's
`.inputObjects()`/`doEvent.BiomeBGC_dataPrep()` pipeline both depend on
network downloads (NTEMS, CanSIS, ORNL, BioSIM, GitHub-hosted CO2/EPC
tables) and a real spatial `studyArea`. A full `simInitAndSpades()`
integration test is a reasonable follow-up, but requires either mocking
those network calls or committing a small real study-area fixture and
accepting long-running, network-dependent tests.

## Running

```r
testthat::test_dir(file.path("tests", "testthat"))
```

or see `tests/testthat/devel-runTests.R` for running individual files.

---
Drafted with assistance from Claude (Posit Assistant).
