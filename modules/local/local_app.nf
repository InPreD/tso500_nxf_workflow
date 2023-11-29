process LOCAL_APP {
    tag "$id"
    label 'process_high'

    container 'docker-oncology.dockerhub.illumina.com/acadia/acadia-500-wdl-workflow:ruo-2.2.0.12'
    containerOptions '--entrypoint=""'

    input:
    tuple val(id), path(runfolder), path(samplesheet), path(fastqfolder), path(json)
    path resourcefolder

    output:
    tuple val(id), path("${output}") , emit: results
    path "versions.yml"              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    samplesheet = samplesheet ? samplesheet : runfolder + "/SampleSheet.csv"
    fastqfolder = fastqfolder ? fastqfolder + "/Logs_Intermediates/FastqGeneration": ""
    output = "localapp_" + id

    """
    sed 's|ANALYSISFOLDER|'`pwd`'|g; s|FASTQFOLDER|'`pwd`/$fastqfolder'|g; s|RESOURCEFOLDER|'`pwd`/$resourcefolder'|g; s|RUNFOLDER|'`pwd`/$runfolder'|g; s|SAMPLESHEETPATH|'`pwd`/$samplesheet'|g' $json > inputs.json
    java \\
        -jar /opt/cromwell/cromwell-36.jar \\
            run \\
            -i inputs.json \\
            /opt/illumina/wdl/TSO500Workflow.wdl
    mkdir $output
    if [ -d "Results" ]; then
        mv Results $output/
    fi
    mv cromwell-executions cromwell-workflow-logs Logs_Intermediates $output/

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cromwell: \$(java -jar /opt/cromwell/cromwell-36.jar --version | sed 's/cromwell //g')
        java: \$(java -version 2>&1 | grep version | sed 's/^openjdk version "\\|"\$//g')
        tso500: \$(grep "TSO500.workflowVersion" inputs.json | sed 's/.*"TSO500.workflowVersion": "\\|"\$//g')
    END_VERSIONS
    """
}

process GATHER {
    tag "$id"
    label 'process_high'

    container 'docker-oncology.dockerhub.illumina.com/acadia/acadia-500-wdl-workflow:ruo-2.2.0.12'
    containerOptions '--entrypoint=""'

    input:
    tuple val(id), path(runfolder), path(samplesheet), path(inputfolders), path(json)
    path resourcefolder

    output:
    tuple val(id), path("cromwell-executions")    , emit: cromwell_executions
    tuple val(id), path("cromwell-workflow-logs") , emit: cromwell_workflow_logs
    tuple val(id), path("inputs.json")            , emit: json
    tuple val(id), path("Logs_Intermediates")     , emit: logs_intermediates
    tuple val(id), path("Results")                , emit: results, optional: true
    path "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    samplesheet = samplesheet ? samplesheet : runfolder + '/SampleSheet.csv'
    def inputfolderlist = '["WORKDIR' + inputfolders.join('","WORKDIR') + '"]'

    """
    sed 's|ANALYSISFOLDER|'`pwd`'|g; s|"INPUTFOLDERLIST"|$inputfolderlist|g; s|RESOURCEFOLDER|'`pwd`/$resourcefolder'|g; s|RUNFOLDER|'`pwd`/$runfolder'|g; s|SAMPLESHEETPATH|'`pwd`/$samplesheet'|g' $json > tmp.json
    sed 's|WORKDIR|'`pwd`'|g' tmp.json > inputs.json
    java \\
        -jar /opt/cromwell/cromwell-36.jar \\
            run \\
            -i inputs.json \\
            /opt/illumina/wdl/GatherResultsWorkflow.wdl

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cromwell: \$(java -jar /opt/cromwell/cromwell-36.jar --version | sed 's/cromwell //g')
        java: \$(java -version 2>&1 | grep version | sed 's/^openjdk version "\\|"\$//g')
        gather: \$(grep "GatherResultsWorkflow.workflowVersion" inputs.json | sed 's/.*"GatherResultsWorkflow.workflowVersion": "\\|"\$//g')
    END_VERSIONS
    """
}
