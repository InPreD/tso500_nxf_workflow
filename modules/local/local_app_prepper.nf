process LOCAL_APP_PREPPER {
    tag "$id"
    label 'process_low'

    container "inpred/local_app_prepper:latest"

    input:
    tuple val(id), path(runfolder), val(sample_list)

    output:
    tuple val(id), path('demultiplex.json') , emit: demultiplex
    tuple val(id), path('gather.json')      , emit: gather
    tuple val(id), path('tso500_*.json')    , emit: tso500
    tuple val(id), path('versions.yml')     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def samples = sample_list.join(',')
    """
    local_app_prepper.py \\
        -i $runfolder \\
        -s $samples

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        local_app_prepper: latest
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
