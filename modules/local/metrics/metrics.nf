process METRICS_PLOTTING {
    tag "${id.size()}_runs"
    label 'process_low'

    container "inpred/tsoppi_main:latest" // is this version v0.3.2?
    containerOptions = "-v \$(pwd):/workdir"

    input:
    tuple val(id), path(tsv, stageAs: "?/*"), path(xml, stageAs: "?/*") // stage file with index as folder name

    output:
    path "intermediate_metrics_files/master_metrics_table.tsv", emit: 'tsv'
    path "TSO500_run_metrics.pdf"                             , emit: 'pdf', optional: true

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    for (int i = 0; i < id.size(); i++) {
        args = args + " -m ${tsv[i]} -r ${xml[i]} -l ${id[i]}"
    }
    """
    bash /inpred/user_scripts/process_metrics_files.sh \\
          --output_directory \$(pwd) \\
          --host_system_mounting_directory \$(pwd) \\
          $args
    """

    stub:
    """
    mkdir intermediate_metrics_files
    touch TSO500_run_metrics.pdf intermediate_metrics_files/master_metrics_table.tsv
    """
}
