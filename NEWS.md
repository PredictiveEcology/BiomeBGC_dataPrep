# BiomeBGC_dataPrep 0.0.1 (19 November 2025)

- initial module version

# BiomeBGC_dataPrep (development)

- The main simulation's `.ini` now starts exactly at `start(sim)` and runs through `end(sim)`,
  instead of also re-simulating the `metSpinupYears`-length spinup period. The spinup remains
  a separate equilibration run over its own dedicated met years (ending the year before
  `start(sim)`), decoupled from the main run's date range.
- The spinup's CO2 concentration is now looked up from the CO2 concentration table for the
  spinup met record's own first calendar year (previously it used the same calendar year as
  the main run's `TIME_DEFINE`, which happened to coincide but was fragile/confusingly
  coupled).
- The main-run meteorological file written by `prepClimateSinglePolygon()` no longer includes
  the spinup years; it now spans only `start(sim)`–`end(sim)`.
- Drafted with assistance from Claude (Posit Assistant).
