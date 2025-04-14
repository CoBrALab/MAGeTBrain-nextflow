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

  publishDir path:"${params.outputDir}/labels/majorityvote/collectedVolumes", mode: "rellink"

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


