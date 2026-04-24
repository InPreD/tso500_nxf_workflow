process ADD_VARIANT_SUMMARY {
    tag "$run_id"
    label 'process_low'

    container "inpred/tsoppi_main:v0.3.2"
    containerOptions "-v \$(pwd):/inpred/data"

    input:
    tuple val(run_id), path(analysis_results_dir)

    output:
    path "${run_id}_variant_summary.tsv", emit: tsv
    path 'versions.yml'                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    python ${params.user_scripts_dir}/summarize_run_variants.py \\
        -r \$(pwd)/${analysis_results_dir} \\
        -o \$(pwd)/${run_id}_variant_summary.tsv \\
        -s \$(pwd) \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        summarize_run_variants: \$(python ${params.user_scripts_dir}/summarize_run_variants.py --version 2>&1 | grep -oP 'version \\K[0-9.:-]+' || echo "0.3.2:22-06-07")
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch ${run_id}_variant_summary.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        summarize_run_variants: stub
        python: stub
    END_VERSIONS
    """
}
