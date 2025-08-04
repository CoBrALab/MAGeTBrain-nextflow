params.useRealData = false
params.inputDir = 'inputs'
params.primarySpectra = 'T1w'

def createMockData() {
    // Create mock atlas-template transforms: [atlasId, templateId, affine, warp]
    atlasTemplateTransforms = Channel.of(
        ['atlas1', 'template1', 'atlas1-template1_0GenericAffine.mat', 'atlas1-template1_1Warp.nii.gz'],
        ['atlas2', 'template2', 'atlas2-template2_0GenericAffine.mat', 'atlas2-template2_1Warp.nii.gz'],
        ['atlas3', 'template3', 'atlas3-template3_0GenericAffine.mat', 'atlas3-template3_1Warp.nii.gz']
    )
    
    // Create mock template-subject transforms: [templateId, subjectId, affine, warp]
    templateSubjectTransforms = Channel.of(
        ['template1', 'subject1', 'template1-subject1_0GenericAffine.mat', 'template1-subject1_1Warp.nii.gz'],
        ['template2', 'subject2', 'template2-subject2_0GenericAffine.mat', 'template2-subject2_1Warp.nii.gz']
    )
    
    // Create mock subjects: [subjectId, maskFile]
    subjects = Channel.of(
        ['subject1', 'subject1_mask.nii.gz'],
        ['subject2', 'subject2_mask.nii.gz'],
        ['subject3', 'subject3_mask.nii.gz'],
        ['subject4', 'subject4_mask.nii.gz'],
        ['subject5', 'subject5_mask.nii.gz'],
        ['subject6', 'subject6_mask.nii.gz']
    )
    
    // Create mock labels: [atlasId, labelFile, labelExt]
    labels = Channel.of(
        ['atlas1', 'atlas1_labels.nii.gz', '_labels'],
        ['atlas2', 'atlas2_labels.nii.gz', '_labels']
    )
    
    return [atlasTemplateTransforms, templateSubjectTransforms, subjects, labels]
}

def createRealData() {
    
    def atlasesDir = file("${params.inputDir}/atlases")
    def subjectsDir = file("${params.inputDir}/subjects")
    def templatesDir = file("${params.inputDir}/templates")

    def T1wPattern = "*${params.primarySpectra}.nii.gz"
    def atlasLabelPattern = "*_label_*.nii.gz"

    def atlases = Channel
        .fromPath("${atlasesDir}/${T1wPattern}") 
        .map { file -> tuple(file.simpleName.minus('_' + params.primarySpectra), file) }
    def labels = Channel
        .fromPath("${atlasesDir}/${atlasLabelPattern}")
        .map { file -> tuple(file.simpleName - ~/_label.*/, (file.simpleName =~ /_label.*/)[0], file) }
    def templates = Channel
        .fromPath("${templatesDir}/${T1wPattern}")
        .map { file -> tuple(file.simpleName.minus('_' + params.primarySpectra), file) }
    def subjects = Channel
        .fromPath("${subjectsDir}/${T1wPattern}")
        .map { file -> tuple(file.simpleName.minus('_' + params.primarySpectra), file) }
    
    def atlasTemplateTransforms = atlases
        .combine(templates)
        .map { atlasId, atlasFile, templateId, templateFile -> 
            [atlasId, templateId, "${atlasId}-${templateId}_0GenericAffine.mat", "${atlasId}-${templateId}_1Warp.nii.gz"] }
    
    def templateSubjectTransforms = templates
        .combine(subjects)
        .map { templateId, templateFile, subjectId, subjectFile -> 
            [templateId, subjectId, "${templateId}-${subjectId}_0GenericAffine.mat", "${templateId}-${subjectId}_1Warp.nii.gz"] }
    
    return [atlasTemplateTransforms, templateSubjectTransforms, subjects, labels]
}

workflow originalMapping {
    take:
        atlasTemplateTransforms
        templateSubjectTransforms
        subjects
        labels
    
    main:
        result = atlasTemplateTransforms
            .map { it -> [ it[1], it[0], it[2], it[3] ] } // [templateId, atlasId, atlasAffine, atlasWarp]
            .combine(templateSubjectTransforms, by: 0)    // by templateId
            .map { it -> [ it[1], it[0], it[2], it[3], it[4], it[5], it[6] ] } // [atlasId, templateId, atlasAffine, atlasWarp, subjectId, templateAffine, templateWarp]
            .combine(labels, by: 0)                       // by atlasId
            .map { it -> [ it[4], it[0], it[1], it[2], it[3], it[5], it[6], it[7], it[8] ] } // [subjectId, atlasId, templateId, atlasAffine, atlasWarp, templateAffine, templateWarp, labelFile, labelExt]
            .combine(subjects, by: 0)                     // by subjectId
            .map { it -> [ it[1], it[2], it[0], it[7], it[3], it[4], it[5], it[6], it[8], it[9] ] } // [atlasId, templateId, subjectId, labelFile, atlasAffine, atlasWarp, templateAffine, templateWarp, labelExt, subjectMask]
    
    emit:
        result
}

workflow refactoredMapping {
    take:
        atlasTemplateTransforms
        templateSubjectTransforms
        subjects
        labels
    
    main:
        atlasTemplate = atlasTemplateTransforms
            .map { atlasId, templateId, atlasAffine, atlasWarp -> [templateId, atlasId, atlasAffine, atlasWarp] }

        templateCombined = atlasTemplate
            .combine(templateSubjectTransforms, by: 0)
            .map { templateId, atlasId, atlasAffine, atlasWarp, subjectId, templateAffine, templateWarp -> 
                   [atlasId, templateId, atlasAffine, atlasWarp, subjectId, templateAffine, templateWarp] }

        labelsCombined = templateCombined
            .combine(labels, by: 0)
            .map { atlasId, templateId, atlasAffine, atlasWarp, subjectId, templateAffine, templateWarp, labelFile, labelExt ->
                   [subjectId, atlasId, templateId, atlasAffine, atlasWarp, templateAffine, templateWarp, labelFile, labelExt] }

        result = labelsCombined
            .combine(subjects, by: 0)
            .map { subjectId, atlasId, templateId, atlasAffine, atlasWarp, templateAffine, templateWarp, labelFile, labelExt, subjectMask ->
                   [atlasId, templateId, subjectId, labelFile, atlasAffine, atlasWarp, templateAffine, templateWarp, labelExt, subjectMask] }
    
    emit:
        result
}

workflow testMappingEquivalence {
    // Use real data if parameter is set, otherwise use mock data
    if (params.useRealData) {
        log.info "Using real data from: ${params.inputDir}"
        (atlasTemplateTransforms, templateSubjectTransforms, subjects, labels) = createRealData()
    } else {
        log.info "Using mock data for testing"
        (atlasTemplateTransforms, templateSubjectTransforms, subjects, labels) = createMockData()
    }
    
    // Use same data for both workflows as it's consumed 
    // and if the channels are gerenated seperately they may be in different order
    atlasTemplateTransforms2 = atlasTemplateTransforms
    templateSubjectTransforms2 = templateSubjectTransforms 
    subjects2 = subjects
    labels2 = labels
    
    originalResult = originalMapping(
        atlasTemplateTransforms, 
        templateSubjectTransforms, 
        subjects, 
        labels
    ).toList()
    
    refactoredResult = refactoredMapping(
        atlasTemplateTransforms2, 
        templateSubjectTransforms2, 
        subjects2, 
        labels2
    ).toList()
    
    originalResult
        .concat(refactoredResult)
        .toList()
        .view { allResults ->
            // as the two results are concat togeter
            // everything before midpoint is original
            // everything after is the refactor
            def midpoint = allResults.size() / 2
            def orig = allResults[0..<midpoint]
            def refact = allResults[midpoint..-1]
             
            orig.sort()
            refact.sort()
            
            def output = new StringBuilder()
            // are they the same?
            output.append("Match: ${orig == refact}\n\n")
            // loop thru and write the outputs
            output.append("ORIGINAL RESULTS:\n")
            orig.eachWithIndex { result, idx ->
                output.append("${idx + 1}. ${result}\n")
            }
            output.append("\nREFACTORED RESULTS:\n")
            refact.eachWithIndex { result, idx ->
                output.append("${idx + 1}. ${result}\n")
            }
            
            new File("comparison.txt").text = output.toString()
            
            return "Done"
        }
}

workflow {
    testMappingEquivalence()
}
