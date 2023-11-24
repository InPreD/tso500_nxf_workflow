
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
    IMPORT MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { CUSTOM_DUMPSOFTWAREVERSIONS        } from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { LOCAL_APP as LOCAL_APP_DEMULTIPLEX } from '../modules/local/local_app'
include { LOCAL_APP as LOCAL_APP_TSO500      } from '../modules/local/local_app'
include { LOCAL_APP_PREPPER                  } from '../modules/local/local_app_prepper'

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
        .map{ it -> return [ it[6], it[7], it[8], [] ] }
        .unique()

    // MODULE: Prepare inputs.json for LocalApp
    LOCAL_APP_PREPPER (
        local_app_prepper_input
    )
    versions = versions.mix(LOCAL_APP_PREPPER.out.versions)

    // attach the json to the correct run folder information
    local_app_demultiplex_input = run_folders.join(LOCAL_APP_PREPPER.out.demultiplex)

    // MODULE: Run LocalApp demultiplex workflow
    LOCAL_APP_DEMULTIPLEX (
        local_app_demultiplex_input,
        ch_tso500_resource_folder
    )
    versions = versions.mix(LOCAL_APP_DEMULTIPLEX.out.versions.first())

    // construct a channel for each sample
    local_app_tso500_input = run_folders
        .join(LOCAL_APP_DEMULTIPLEX.out.logs_intermediates)
        .join(LOCAL_APP_PREPPER.out.tso500.transpose())
        .map{ construct_fastq_folder_path(it) }
        .view()

    // MODULE: Run LocalApp TSO500 workflow
    LOCAL_APP_TSO500 (
        local_app_tso500_input,
        ch_tso500_resource_folder
    )

    // MODULE: Run LocalApp Gather workflow
    LOCAL_APP_PREPPER.out.gather.view()

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
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS FOR CHANNEL MANIPULATION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def construct_fastq_folder_path(it) {
    def path_str = it[5].toString()
    def sample_id = path_str.substring(path_str.lastIndexOf('/') + 1).replace('tso500_', '').replace('.json', '')
    def fastq_folder_path = it[4] + "FastqGeneration/" + sample_id
    return [ sample_id, it[1], it[2], fastq_folder_path, it[5] ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
