/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { validateParameters; paramsHelp; paramsSummaryLog; fromSamplesheet } from 'plugin/nf-validation'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Check input path parameters to see if they exist
def checkPathParamList = [ params.input ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
//if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input not specified!' }
ch_input = Channel.fromSamplesheet("input")
if (params.tso500_resource_folder) { ch_tso500_resource_folder = file(params.tso500_resource_folder) } else { exit 1, 'TSO500 resource folder not specified!' }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { CUSTOM_DUMPSOFTWAREVERSIONS        } from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { GATHER                             } from '../modules/local/local_app'
include { LOCAL_APP as LOCAL_APP_DEMULTIPLEX } from '../modules/local/local_app'
include { LOCAL_APP as LOCAL_APP_TSO500      } from '../modules/local/local_app'
include { LOCAL_APP_PREPPER                  } from '../modules/local/local_app_prepper'

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
        .join(LOCAL_APP_DEMULTIPLEX.out.results)
        .combine(LOCAL_APP_PREPPER.out.tso500.transpose(), by: 0)
        .map{ it -> return [ get_sample_id(it[5]), it[1], it[2], it[4], it[5] ] }

    // MODULE: Run LocalApp TSO500 workflow
    LOCAL_APP_TSO500 (
        local_app_tso500_input,
        ch_tso500_resource_folder
    )
    versions = versions.mix(LOCAL_APP_TSO500.out.versions.first())

    // MODULE: Run LocalApp Gather workflow
    gather_inputfolders = LOCAL_APP_PREPPER.out.tso500.transpose()
        .map{ it -> return [ get_sample_id(it[1]), it[0] ] }
        .join(LOCAL_APP_TSO500.out.results)
        .map{ it -> return [ it[1], it[2] ] }
        .concat(LOCAL_APP_DEMULTIPLEX.out.results)
        .groupTuple()
    gather_input = run_folders
        .map{ it -> return [ it[0], it[1], it[2] ] }
        .join(gather_inputfolders)
        .join(LOCAL_APP_PREPPER.out.gather)

    GATHER (
        gather_input,
        ch_tso500_resource_folder
    )
    versions = versions.mix(GATHER.out.versions.first())

    CUSTOM_DUMPSOFTWAREVERSIONS (
        versions.unique().collectFile(name: 'collated_versions.yml')
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

def get_sample_id(it) {
    def path_str = it.toString()
    def sample_id = path_str.substring(path_str.lastIndexOf('/') + 1).replace('tso500_', '').replace('.json', '')
    return sample_id
}
