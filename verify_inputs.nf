params.primarySpectra = 'T1w'
params.inputDir = 'inputs'
params.outputDir = 'output'

params.atlasesDir = "${params.inputDir}/atlases"
params.subjectsDir = "${params.inputDir}/subjects"
params.templatesDir = "${params.inputDir}/templates"

params.atlasT1wPattern = "*${params.primarySpectra}.nii.gz"
params.atlasLabelPattern = "atlas*_label_*.nii.gz"
params.atlasCsvPattern = "volume_labels_*.csv"
params.subjectT1wPattern = "*${params.primarySpectra}.nii.gz"
params.templateT1wPattern = "*${params.primarySpectra}.nii.gz"

workflow {
    log.info """
    =====================================================
    FILE STRUCTURE VERIFICATION
    =====================================================
    Input directory: ${params.inputDir}
    """
    verify_structure()
    
    // subscribe used for side effects, like printing, writing, HTTP requests
    verify_structure.out.subscribe { 
        log.info it 
        if (!it.toString().contains("User confirmed")) {
            log.info "Verification failed or was aborted by user"
            System.exit(1)
        }
    }
}

process verify_structure {
    input:

    output:
    stdout

    script:
    """
    # Check atlases directory
    if [ ! -d "${params.atlasesDir}" ]; then
        echo "ERROR: ${params.atlasesDir} directory not found"
        exit 1
    fi
    
    # Check for atlas files
    atlas_T1w_count=\$(ls ${params.atlasesDir}/${params.atlasT1wPattern} 2>/dev/null | wc -l)
    atlas_label_count=\$(ls ${params.atlasesDir}/${params.atlasLabelPattern} 2>/dev/null | wc -l)
    csv_count=\$(ls ${params.atlasesDir}/${params.atlasCsvPattern} 2>/dev/null | wc -l)
    
    if [ \$atlas_T1w_count -eq 0 ]; then
        echo "WARNING: No atlas ${params.primarySpectra} files found in ${params.atlasesDir}"
        exit 1
    fi
    
    if [ \$atlas_label_count -eq 0 ]; then
        echo "WARNING: No atlas label files found in ${params.atlasesDir}"
        exit 1
    fi
    
    if [ \$csv_count -eq 0 ]; then
        echo "WARNING: No CSV label files found in ${params.atlasesDir}"
    fi
    
    # Check subjects directory
    if [ ! -d "${params.subjectsDir}" ]; then
        echo "ERROR: ${params.subjectsDir} directory not found"
        exit 1
    fi
    
    subject_count=\$(ls ${params.subjectsDir}/${params.subjectT1wPattern} 2>/dev/null | wc -l)
    if [ \$subject_count -eq 0 ]; then
        echo "ERROR: No subject ${params.primarySpectra} files found in ${params.subjectsDir}"
        exit 1
    else
        echo "Found \$subject_count subject files"
    fi
    
    # Check templates directory
    if [ ! -d "${params.templatesDir}" ]; then
        echo "ERROR: ${params.templatesDir} directory not found"
        exit 1
    fi
    
    template_count=\$(ls ${params.templatesDir}/${params.templateT1wPattern} 2>/dev/null | wc -l)
    if [ \$template_count -eq 0 ]; then
        echo "WARNING: No template ${params.primarySpectra} files found in ${params.templatesDir}"
    else
        echo "Found \$template_count template files"
    fi
    
    # Print structure for user verification
    echo "===== DIRECTORY STRUCTURE VERIFICATION ====="
    echo "Atlases directory: \$(ls ${params.atlasesDir})"
    echo "Subjects directory: \$(ls ${params.subjectsDir})"
    echo "Templates directory: \$(ls ${params.templatesDir})"
    echo "============================================"
    
    # Ask for user confirmation
    echo "Do you want to continue with this file structure? [y/N]"
    read -r response
    if [[ \$response =~ ^[Yy] ]]; then
        echo "User confirmed. Proceeding with workflow."
    else
        echo "User aborted. Exiting workflow."
        exit 1
    fi
    """
}
