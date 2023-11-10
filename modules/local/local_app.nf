process LOCAL_APP {
    tag "$id"
    label 'process_high'

    container 'docker-oncology.dockerhub.illumina.com/acadia/acadia-500-wdl-workflow:ruo-2.2.0.12'
    containerOptions '--entrypoint=""'

    input:
    path runfolder
    path samplesheet
    path json
    path resourcefolder

    output:
    path "cromwell-executions"   , emit: cromwell-executions
    path "cromwell-workflow-logs", emit: cromwell-workflow-logs
    path "inputs.json"           , emit: json
    path "Logs_Intermediates"    , emit: logs-intermediates
    path "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    samplesheet = samplesheet ? samplesheet : runfolder + "/SampleSheet.csv"

    """
    sed 's|ANALYSISFOLDER|'`pwd`'|g; s|RESOURCEFOLDER|'`pwd`/$resourcefolder'|g; s|RUNFOLDER|'`pwd`/$runfolder'|g; s|SAMPLESHEETPATH|'`pwd`/$samplesheet'|g' $json > inputs.json
    java \\
        -jar /opt/cromwell/cromwell-36.jar \\
            run \\
            -i inputs.json \\
            /opt/illumina/wdl/TSO500Workflow.wdl

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cromwell: \$(java -jar /opt/cromwell/cromwell-36.jar --version | sed 's/cromwell //g')
        java: \$(java -version 2>&1 | grep version | sed 's/^openjdk version "\\|"\$//g')
        tso500: \$(grep "TSO500.workflowVersion" input.json | sed 's/.*"TSO500.workflowVersion": "\\|"\$//g)
    END_VERSIONS
    """
}