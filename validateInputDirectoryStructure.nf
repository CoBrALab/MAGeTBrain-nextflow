  workflow validateInputDirectoryStructure {
    main:
        log.info """
        ========================================
        Input Directory Validation
        ========================================
        Input Dir:      ${params.inputDir}
        Primary Spectra: ${params.primarySpectra}
        """
        def inputDirPath = file(params.inputDir)
        if (!inputDirPath.isDirectory()) {
            error "ERROR: Input directory not found or is not a directory: ${params.inputDir}"
        }

        def atlasesDir = file("${params.inputDir}/atlases")
        def subjectsDir = file("${params.inputDir}/subjects")
        def templatesDir = file("${params.inputDir}/templates")
            

        if (!atlasesDir.isDirectory()) { error "ERROR: Atlases directory not found: ${atlasesDir}" }
        if (!subjectsDir.isDirectory()) { error "ERROR: Subjects directory not found: ${subjectsDir}" }
        if (!templatesDir.isDirectory()) { error "ERROR: Templates directory not found: ${templatesDir}" }

        log.info"""
        Found required subdirectories: atlases, subjects, templates.
        """

        def T1wPattern = "*${params.primarySpectra}.nii.gz"
        def atlasLabelPattern = "*_label_*.nii.gz"
        def atlasCsvPattern = "volume_labels_*.csv"

        def atlasT1wCount = files("${atlasesDir}/${T1wPattern}").size() 
        def atlasLabelCount = files("${atlasesDir}/${atlasLabelPattern}").size()
        def csvCount = files("${atlasesDir}/${atlasCsvPattern}").size()
        def subjectCount = files("${subjectsDir}/${T1wPattern}").size()
        def templateCount = files("${templatesDir}/${T1wPattern}").size()

        def isValid = true

        if (atlasT1wCount == 0) {
            log.error "ERROR: No atlas ${params.primarySpectra} files matching '${T1wPattern}' found in ${atlasesDir}"
            isValid = false
        } else {
             log.info """
             Found ${atlasT1wCount} atlas ${params.primarySpectra} files."""
        }

        if (atlasLabelCount == 0) {
             log.error "ERROR: No atlas label files matching '${atlasLabelPattern}' found in ${atlasesDir}"
             isValid = false
        } else {
             log.info """
             Found ${atlasLabelCount} atlas label files."""
             
        }

        if (csvCount == 0) {
             log.warn "WARNING: No CSV label files matching '${atlasCsvPattern}' found in ${atlasesDir}"
        } else {
            log.info """
            Found ${csvCount} CSV label files."""
        }

        if (subjectCount == 0) {
             log.error "ERROR: No subject ${params.primarySpectra} files matching '${T1wPattern}' found in ${subjectsDir}"
             isValid = false } else {
            log.info """
            Found $subjectCount subject ${params.primarySpectra} files."""
        }

        if (templateCount == 0) {
             log.error "ERROR: No template ${params.primarySpectra} files matching '${T1wPattern}' found in ${templatesDir}"
                isValid = false
        } else {
            log.info """
            Found $templateCount template ${params.primarySpectra} files."""

        }

        if (!isValid) {
            error "Input validation failed. Please check errors above."
        }

        log.info """
        ========================================
        Validation Complete. Creating Channels.
        ========================================
        """
} 

workflow{

    
validateInputDirectoryStructure()
}
