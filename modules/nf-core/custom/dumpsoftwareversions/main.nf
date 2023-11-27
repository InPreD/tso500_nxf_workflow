process CUSTOM_DUMPSOFTWAREVERSIONS {
    label 'process_single'

    container "quay.io/biocontainers/multiqc:1.13--pyhdfd78af_0"

    input:
    path versions

    output:
    path "software_versions.yml"    , emit: yml
    path "versions.yml"             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    template 'dumpsoftwareversions.py'

    stub:
    """
    touch software_versions.yml
    touch versions.yml
    """
}
