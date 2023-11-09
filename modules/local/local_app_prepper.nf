process LOCAL_APP_PREPPER {
    tag "$id"
    label 'process_low'

    container "inpred/local_app_prepper:latest"

    input:
    path runfolder

    output:
    path 'gather.json' , emit: gather
    path 'tso500.json' , emit: tso500
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    local_app_prepper.py \\
        -i $run_folder

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        local_app_prepper: latest
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
