## Pre-install BioSIM and its dependency J4R *serially*, one at a time, before any
## other step calls Require::Require() on the module's full reqdPkgs vector.
##
## Root cause: pak's parallel "identify-and-defer" install strategy can start
## building BioSIM before J4R (BioSIM's Imports: dependency) has finished
## installing, in the same batched Require::Require(pkgs) call the CI workflow
## uses for all of reqdPkgs at once. When that race is lost, BioSIM is left
## uninstalled -- even though J4R installs successfully -- and the warning is
## non-fatal, so the step "succeeds" but a later step then fails because BioSIM
## is missing. Installing J4R and BioSIM one at a time here, before that batched
## call runs, avoids ever giving pak the chance to schedule them as parallel
## siblings. This file is sourced automatically at the start of every 
## invocation (including each CI workflow step), so it is a no-op once both
## packages are already installed.
##
## Drafted with assistance from Claude (Posit Assistant).
local({
  needsInstall <- function(pkg) !requireNamespace(pkg, quietly = TRUE)
  if (requireNamespace("Require", quietly = TRUE)) {
    if (needsInstall("J4R")) {
      try(Require::Require("CWFC-CCFB/J4R", require = FALSE), silent = TRUE)
    }
    if (needsInstall("BioSIM")) {
      try(Require::Require("RNCan/BioSimClient_R", require = FALSE), silent = TRUE)
    }
  }
})
