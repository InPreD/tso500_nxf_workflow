process PROCESS_METRICS_FILES {
    tag "${id.size()}_runs"
    label 'process_low'

    container "inpred/tsoppi_main:latest" // is this version v0.3.2?
    containerOptions = "-v \$(pwd):/workdir -v \$(pwd):/inpred/data"

    input:
    tuple val(id), path(tsv, stageAs: "?/*"), path(xml, stageAs: "?/*") // stage file with index as folder name

    output:
    path "intermediate_metrics_files/master_metrics_table.tsv" , emit: 'tsv'
    path "TSO500_run_metrics.pdf"                              , emit: 'pdf', optional: true
    path 'versions.yml'                                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    for (int i = 0; i < id.size(); i++) {
        args = args + " -m \$(pwd)/${tsv[i]} -r \$(pwd)/${xml[i]} -l ${id[i]}" // due to tsoppi container replacing absolute input mount paths we need to create absolute paths for staged files
    }
    """
    bash /inpred/user_scripts/process_metrics_files.sh \\
        --output_directory \$(pwd) \\
        --host_system_mounting_directory \$(pwd) \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        process_metrics_files: \$(bash /inpred/user_scripts/process_metrics_files.sh --version | grep process_metrics_files.py | awk '{print \$2}')
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    mkdir intermediate_metrics_files
    touch TSO500_run_metrics.pdf intermediate_metrics_files/master_metrics_table.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        process_metrics_files: stub
        python: stub
    END_VERSIONS
    """
}
