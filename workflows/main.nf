
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// TODO: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.input ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
//if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input not specified!' }
if (params.tso500_resource_folder) { ch_tso500_resource_folder = file(params.tso500_resource_folder) } else { exit 1, 'TSO500 resource folder not specified!' }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// TODO: Add config files required for running the different bioinformatic tools 
// These files do not necessarily contain the extension ".config"
// e.g. the multiqc_config.yaml providing config for multiqc

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { LOCAL_APP_DEMULTIPLEX       } from '../modules/local/local_app'
include { LOCAL_APP_PREPPER           } from '../modules/local/local_app_prepper'

include { validateParameters; paramsHelp; paramsSummaryLog; fromSamplesheet } from 'plugin/nf-validation'

ch_input = Channel.fromSamplesheet("input")

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow MAIN {

    // empty channel to store all software versions
    versions = Channel.empty()

    // channel holding information about run id, path to the run folder and a list of sample ids
    local_app_prepper_input = ch_input
        .map{ it -> return [ it[6], it[7], it[1] ] }
        .groupTuple( by: [ 0, 1 ] )

    // channel holding information about run id, path to run folder and samplesheet
    run_folders = ch_input
        .map{ it -> return [ it[6], it[7], it[8] ] }
        .unique()

    // MODULE: Prepare inputs.json for LocalApp
    LOCAL_APP_PREPPER (
        local_app_prepper_input
    )
    versions = versions.mix(LOCAL_APP_PREPPER.out.versions)

    // attach the json to the correct run folder information
    local_app_demultiplex_input = run_folders.join(LOCAL_APP_PREPPER.out.demultiplex)
    LOCAL_APP_PREPPER.out.tso500.view()
    LOCAL_APP_PREPPER.out.tso500.gather()

    // MODULE: Run LocalApp TSO500 workflow
    LOCAL_APP_DEMULTIPLEX (
        local_app_demultiplex_input,
        ch_tso500_resource_folder
    )
    versions = versions.mix(LOCAL_APP.out.versions.first())

    CUSTOM_DUMPSOFTWAREVERSIONS (
        versions.unique{ it.text }.collectFile(name: 'collated_versions.yml')
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    NfcoreTemplate.summary(workflow, params, log)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
