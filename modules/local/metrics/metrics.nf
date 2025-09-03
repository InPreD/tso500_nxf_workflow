process METRICS_PLOTTING {
    tag "${run_ids.size()}_runs"
    label 'process_low'

    container "${docker_image_id}"
    containerOptions = "-v ${params.local_mounting_dir}:/inpred/data -v \$(pwd):/workdir"

    input:
    val run_ids
    val final_output_dir
    val docker_image_id
    output:
    path "intermediate_metrics_files/master_metrics_table.tsv"  , emit: 'tsv'
    path "TSO500_run_metrics.pdf"                             , emit: 'pdf', optional: true
    when:
    task.ext.when == null || task.ext.when

    script:
    def argument_list = run_ids.collect { run_id ->
        "-m ${params.local_mounting_dir}/in/analysis_results/${run_id}_TSO_500_LocalApp_results/Results/MetricsOutput.tsv " +
        "-r ${params.local_mounting_dir}/in/sequences/decoy_RunCompletionStatus.xml " +
        "-l ${run_id}"
    }.join(' ')

    """
    bash /inpred/user_scripts/process_metrics_files.sh \\
          ${argument_list} \\
          -o \$(pwd) \\
          -s ${params.local_mounting_dir} \\
          ${task.ext.args ?: ''}

    """

    stub:
    """
    mkdir -p ${final_output_dir}
    touch ${final_output_dir}/TSO500_metrics_plots.pdf
    touch ${final_output_dir}/master_metrics_table.tsv
    """
}
