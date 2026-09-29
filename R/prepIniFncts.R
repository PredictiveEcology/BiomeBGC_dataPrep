prepSpinupIni <- function(pixelGroupParameters, iniTemplate, userParams, species_lookup, Ndep_yr2){
  
  # Create a list of ini files: 1 file per pixelGroup
  nPixelGroups <- nrow(pixelGroupParameters)
  bbgcSpinup.ini <- vector("list", nPixelGroups)
  restartPath <- file.path("inputs", "restart")
  
  pixelGroup_chunks <- seq_len(nPixelGroups)
  
  bbgcSpinup.ini <- lapply(
    X = pixelGroup_chunks,
    FUN = prepSpinupIni_worker,
    iniTemplate = iniTemplate,
    pixelGroupParameters = pixelGroupParameters,
    restartPath = restartPath,
    userParams = userParams,
    species_lookup = species_lookup,
    Ndep_yr2 = Ndep_yr2
  )
  
  # Add to name of pixelGroup
  names(bbgcSpinup.ini) <- pixelGroupParameters$pixelGroup
  
  return(bbgcSpinup.ini)
  
}

prepSpinupIni_worker <- function(pixelGroup_i, iniTemplate, pixelGroupParameters, restartPath, userParams, species_lookup, Ndep_yr2){
  # First read the ini template
  spinupIni <- iniTemplate
  parameters <- pixelGroupParameters[pixelGroup_i, ]
  
  ## Set MET_INPUT section
  fileName <- paste0(parameters$climatePolygon, "_spinup.mtc43")
  spinupIni <- iniSet(spinupIni,
                      "MET_INPUT",
                      1,
                      file.path("inputs", "metdata", fileName))
  
  ## Set RESTART section
  spinupIni <- iniSet(spinupIni,
                      "RESTART",
                      c(5, 6),
                      file.path(restartPath, paste0(parameters$pixelGroup, ".restart")))
  
  ## Set SITE section
  # For each check if NA, if it is get the value from different sources
  # Soil depth
  if(is.na(userParams$siteConstants[1])){
    spinupIni <- iniSet(spinupIni, "SITE", 1,
                        parameters$soilDepth)
  } else {
    spinupIni <- iniSet(spinupIni, "SITE", 1,
                        userParams$siteConstants[1])
  }
  
  # Soil texture: % of sand, % of silt, % of clay
  if(is.na(userParams$siteConstants[2])){
    spinupIni <- iniSet(spinupIni, "SITE", c(2:4),
                        c(parameters$soilSandContent,
                          parameters$soilSiltContent,
                          parameters$soilClayContent))
  } else {
    spinupIni <- iniSet(spinupIni, "SITE", c(2:4),
                        userParams$siteConstants[c(2:4)])
  }
  
  # Elevation
  if(is.na(userParams$siteConstants[5])){
    spinupIni <- iniSet(spinupIni, "SITE", 5, parameters$elevation)
  } else {
    spinupIni <- iniSet(spinupIni, "SITE", 5, userParams$siteConstants[5])
  }
  
  # Latitude
  if (is.na(userParams$siteConstants[6])) {
    spinupIni <- iniSet(spinupIni, "SITE", 6, parameters$latitude)
  } else {
    spinupIni <- iniSet(spinupIni, "SITE", 6, userParams$siteConstants[6])
  }
  
  # Site shortwave albedo
  if (is.na(userParams$siteConstants[7])) {
    spinupIni <- iniSet(spinupIni, "SITE", 7, parameters$soilAlbedo)
  } else {
    spinupIni <- iniSet(spinupIni, "SITE", 7, userParams$siteConstants[7])
  }
  
  # wet+dry atmospheric deposition of N
  if (is.na(userParams$siteConstants[8])) {
    spinupIni <- iniSet(spinupIni,
                        "SITE",
                        8,
                        format(
                          parameters$NdepositionT1,
                          scientific = FALSE,
                          trim = TRUE
                        ))
  } else {
    spinupIni <- iniSet(spinupIni, "SITE", 8, userParams$siteConstants[8])
  }
  
  # symbiotic+asymbiotic fixation of N
  if (is.na(userParams$siteConstants[9])) {
    spinupIni <- iniSet(spinupIni,
                        "SITE",
                        9,
                        format(
                          parameters$NfixationRate,
                          scientific = FALSE,
                          trim = TRUE
                        ))
  } else {
    spinupIni <- iniSet(spinupIni, "SITE", 9, userParams$siteConstants[9])
  }
  
  # Set RAMP_NDEP section
  if(userParams$NDepositionLevel[1] == 1 & is.na(userParams$NDepositionLevel[2])){
    Ndeposition2 <- parameters$NdepositionT2
    spinupIni <- iniSet(spinupIni, "RAMP_NDEP", c(2, 3),
                        c(Ndep_yr2,
                          format(Ndeposition2, scientific = FALSE, trim = TRUE))
    )
  } else if (userParams$NDepositionLevel[1] == 1 & !is.na(userParams$NDepositionLevel[2])){
    spinupIni <- iniSet(spinupIni, "RAMP_NDEP", c(2,3), userParams$NDepositionLevel[c(2,3)])
  }
  
  # Set EPC_FILE section
  # extract the correct dominant species
  dominantSpecies <- species_lookup[[parameters$dominantSpecies]]
  # set filename
  fileName <- tolower(paste0(gsub(" ", "", dominantSpecies), ".epc"))
  # set in ini file
  spinupIni <- iniSet(spinupIni, "EPC_FILE", 1, file.path("inputs", "epc", fileName))
  
  # Set W_STATE section
  if(is.na(userParams$waterState[1])){
    spinupIni <- iniSet(spinupIni, "W_STATE", 1, parameters$snowPackWaterContent)
  } else {
    spinupIni <- iniSet(spinupIni, "W_STATE", 1, userParams$waterState[1])
  }
  
  return(spinupIni)
}

