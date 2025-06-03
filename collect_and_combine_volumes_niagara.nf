include {combineVolumes} from "./collect_and_combine_volumes.nf"
include {collectVolumes}  from "./collect_and_combine_volumes.nf"
workflow {
    niftiFiles = Channel.fromPath("${params.outputDir}/labels/majorityvote/*.nii.gz")

    niftiFiles
        .map { a_file ->
            def matcher = a_file.name =~ /_label_([\w]+)\.nii.gz/
            if (matcher.find()) {
                def label = matcher.group(1)
                def csvFile = file("${params.inputDir}/atlases/volume_labels_${label}.csv")
                
                if (csvFile.exists()) {
                    return [csvFile, a_file]  
                } else {
                    return [file("NO_FILE"), a_file]  
                }
            } else {
                return null
            }
        }
        .set { filesToProcess }

    volumes = collectVolumes(filesToProcess)
    combineVolumes(volumes.collect())
}
