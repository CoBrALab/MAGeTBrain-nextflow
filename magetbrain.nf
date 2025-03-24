params.primarySpectra = 'T1w'
params.inputDir = 'inputs'
params.outputDir = 'output'
params.fast = ''
process registerAffine {
  label 'registerAffine'
  cpus 8
  // memory { 32.GB * task.attempt }
  // memory '32GB'
  // time { 30.minutes * 1.5 * task.attempt }
  // errorStrategy 'retry'
  // maxRetries 4

  input:
    tuple val(movingId), path('moving.nii.gz'), val(fixedId), path('fixed.nii.gz')

  output:
    tuple val(movingId), path('moving.nii.gz'), emit: moving
    tuple val(fixedId), path('fixed.nii.gz'), emit: fixed
    path "${movingId}-${fixedId}_0GenericAffine.mat", emit: affine

  script:
    """
    ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${task.cpus} \
    antsRegistration_affine_SyN.sh \
      --clobber \
      --skip-nonlinear \
      moving.nii.gz \
      fixed.nii.gz \
      ${movingId}-${fixedId}_
    """

  stub:
    """
    echo antsRegistration_affine_SyN.sh \
      --clobber \
      --skip-nonlinear \
      moving.nii.gz \
      fixed.nii.gz \
      ${movingId}-${fixedId}_
    touch ${movingId}-${fixedId}_0GenericAffine.mat
    """
}

process registerNonlinear {
  label 'registerNonlinear'
  cpus 8
  // memory '32GB'
  // memory { 10.GB * 1.5 * task.attempt }
  // time { 4.hours * 1.5 * task.attempt }
  // errorStrategy 'retry'
  // maxRetries 4

  input:
    tuple val(movingId), path('moving.nii.gz')
    tuple val(fixedId), path('fixed.nii.gz')
    path affineInitializationPath

  output:
    tuple val(movingId),
          val(fixedId),
          path("${movingId}-${fixedId}_0GenericAffine.mat"),
          path("${movingId}-${fixedId}_1Warp.nii.gz")

  script:
    """
    ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${task.cpus} \
    antsRegistration_affine_SyN.sh \
      --clobber \
      --initial-transform ${affineInitializationPath} \
      --skip-linear \
      moving.nii.gz \
      fixed.nii.gz \
      ${movingId}-${fixedId}_
    """

  stub:
    """
    echo antsRegistration_affine_SyN.sh \
      --clobber \
      --initial-transform ${affineInitializationPath} \
      moving.nii.gz \
      fixed.nii.gz \
      ${movingId}-${fixedId}_
    touch ${movingId}-${fixedId}_0GenericAffine.mat
    touch ${movingId}-${fixedId}_1Warp.nii.gz
    touch ${movingId}-${fixedId}_1InverseWarp.nii.gz
    """
}

process resampleLabel {
  label 'resampleLabel'
  cpus 1
  // memory '4GB'
  // time '15min'

  input:
    tuple val(atlasId),
          val(templateId),
          val(subjectId),
          val(labelExt),
          path(atlasTemplateAffinePath),
          path(atlasTemplateWarpPath),
          path(templateSubjectAffinePath),
          path(templateSubjectWarpPath),
          path(labelPath),
          path(subjectPath)

  output:
    tuple val(subjectId),
          val(labelExt),
          path('candidateLabel.nii.gz')

    script:
    """
    ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${task.cpus} \
    antsApplyTransforms -d 3 --verbose \
      -n GenericLabel \
      -r ${subjectPath} \
      -i ${labelPath} \
      -t ${templateSubjectWarpPath} \
      -t ${templateSubjectAffinePath} \
      -t ${atlasTemplateWarpPath} \
      -t ${atlasTemplateAffinePath} \
      -o candidateLabel.nii.gz
    """

  stub:
    """
    echo antsApplyTransforms -d 3 --verbose \
      -n GenericLabel \
      -r ${subjectPath} \
      -i ${labelPath} \
      -t ${templateSubjectWarpPath} \
      -t ${templateSubjectAffinePath} \
      -t ${atlasTemplateWarpPath} \
      -t ${atlasTemplateAffinePath} \
      -o candidateLabel.nii.gz
    touch candidateLabel.nii.gz
    """
}

process majorityVote {
  label 'majorityVote'
  cpus 4
  // memory '16GB'
  // time '30min'

  publishDir 'output/labels/majorityvote'

  input:
    tuple val(subjectId),
          val(labelExt),
          path('candidate?.nii.gz')

  output:
    path "${subjectId}${labelExt}.nii.gz"

  script:
  """
  ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${task.cpus} \
  ImageMath 3 ${subjectId}${labelExt}.nii.gz MajorityVoting candidate?.nii.gz
  """

  stub:
  """
  echo ImageMath 3 ${subjectId}${labelExt}.nii.gz MajorityVoting candidate?.nii.gz
  touch ${subjectId}${labelExt}.nii.gz
  """
}

process collectVolumes {
  label 'collectVolumes'
  cpus 4
  // memory '16GB'
  // time '30min'


  input:
    tuple path(labelCsv), path(input)  

  output:
    path "${input.baseName}_volume_output.tsv"

  script:
    
    def labelCsvArg = labelCsv.name != 'NO_FILE' ? "${labelCsv}" : ""
    """
    collect_volumes_nifti.sh ${labelCsvArg} ${input} > ${input.baseName}_volume_output.tsv
    """

  stub:
    def labelCsvArg = labelCsv.name != 'NO_FILE' ? "${labelCsv}" : ""
    """
    echo collect_volumes_nifti.sh ${labelCsvArg} ${input} > ${input.baseName}_volume_output.tsv
    """
}

process combineVolumes {

  publishDir path:"${params.outputDir}/labels/majorityvote/collectedVolumes"

  input:
    path files 
  output:
    path "combined_volume_output.tsv"

  script:
    """
    cat ${files[0]} > combined_volume_output.tsv
    for file in ${files.tail().join(" ")}; do
        tail -n +2 \$file >> combined_volume_output.tsv
    done
    """
}

workflow resampleCanditateLabels {
  take:
    atlasTemplateTransforms
    templateSubjectTransforms
    subjects
    labels

  main:
    // Use map to reorder the atlasTemplateTransforms map, because combine cannot use anything other than the first column
    // Combine the maps to produce all possible paths
    atlasTemplateTransforms
                          .map { it -> [ it[1], it[0], it[2], it[3] ] }
                          .combine(templateSubjectTransforms, by: 0)
                          .map { it -> [ it[1], it[0], it[2], it[3], it[4], it[5], it[6] ] }
                          .combine(labels, by: 0)
                          .map { it -> [ it[4], it[0], it[1], it[2], it[3], it[5], it[6], it[7], it[8] ] }
                          .combine(subjects, by: 0)
                          .map { it -> [ it[1], it[2], it[0], it[7], it[3], it[4], it[5], it[6], it[8], it[9] ] }
                          | resampleLabel

  emit:
    resampleLabel.out
}

workflow registerAtlasesTemplates {
  take:
    atlases
    templates

  main:
    // Combine produces an output where every atlas is applied to every template
    def atlasTemplatePairs = atlases.combine(templates)
    // Run registration by performing affine followed by nonlinear
    atlasTemplatePairs | registerAffine | registerNonlinear

  emit:
    transforms = registerNonlinear.out
}

workflow registerTemplatesSubjects {
  take:
    templates
    subjects

  main:
    // Combine produces an output where every template is applied to every subject
    def templateSubjectPairs = templates.combine(subjects)
    // Run registration by performing affine followed by nonlinear
    templateSubjectPairs | registerAffine | registerNonlinear

  emit:
    transforms = registerNonlinear.out
    subjects = subjects
}

workflow MAGeTBrain {
  take:
    atlases
    labels
    templates
    subjects

  main:
    // Run atlas-template registration
    registerAtlasesTemplates(atlases, templates)
    // Run template-subject registration
    registerTemplatesSubjects(templates, subjects)
    // Use transforms to resample all candidate labels to subject space
    resampleCanditateLabels(registerAtlasesTemplates.out.transforms, registerTemplatesSubjects.out.transforms, subjects, labels)
    | groupTuple(by: [0, 1]) | majorityVote

    emit: 
        majorityVoteOutput = majorityVote.out

    
}

workflow {
  // Read in atlas files, use primarySpectra option to determine which will be the primary match
  // map the filename to a subject ID for later use
  def atlases = Channel.fromPath('inputs/atlases/*_' + params.primarySpectra + '.nii.gz')
                      .map { file -> tuple(file.simpleName.minus('_' + params.primarySpectra), file) }
  // Read in labels
  def labels = Channel.fromPath( 'inputs/atlases/*_label_*.nii.gz' )
                      .map { file -> tuple(file.simpleName - ~/_label.*/, (file.simpleName =~ /_label.*/)[0], file) }
  // Read in templates
  def templates = Channel.fromPath('inputs/templates/*_' + params.primarySpectra + '.nii.gz')
                      .map { file -> tuple(file.simpleName.minus('_' + params.primarySpectra), file) }
  // Read in subjects
  def subjects = Channel.fromPath( 'inputs/subjects/*_' + params.primarySpectra + '.nii.gz' )
                      .map { file -> tuple(file.simpleName.minus('_' + params.primarySpectra), file) }

  // Run MAGeTBrain 
  def majorityVoteOutput = MAGeTBrain(atlases, labels, templates, subjects)
    
    // set the majorityVoteOutput as filesToProcess and check to if a label.csv file exists
    majorityVoteOutput
        .map { a_file ->
            def matcher = a_file.name =~ /_label_([\w]+)\.nii.gz/
            if (matcher.find()) {
                def label = matcher.group(1)
                def csvFile = file("${params.inputDir}/atlases/volume_label_${label}.csv")
                
                if (csvFile.exists()) {
                    return [csvFile, a_file]  
                } else {
                    return [file("NO_FILE"), a_file]  
                }
            } else {
                // if the file match does not exists null will be returned
                // nextflow automatically handles nulls
                return null  
            }
        }
        .set { filesToProcess }
    // collect the volumes and combine results
    volumes = collectVolumes(filesToProcess)
    // after all files process they will be collected
    combineVolumes(volumes.collect())
    }

