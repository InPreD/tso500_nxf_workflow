/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { GATHER                                    } from '../modules/local/local_app/local_app'
include { LOCAL_APP as LOCAL_APP_DEMULTIPLEX        } from '../modules/local/local_app/local_app'
include { LOCAL_APP as LOCAL_APP_TSO500             } from '../modules/local/local_app/local_app'
include { LOCAL_APP_PREPPER                         } from '../modules/local/local_app_prepper/local_app_prepper'
include { paramsSummaryMap                          } from 'plugin/nf-schema'
include { samplesheetToList                         } from 'plugin/nf-schema'
include { softwareVersionsToYAML                    } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { validateParameters                        } from 'plugin/nf-schema'
include { METRICS_PLOTTING as ALL_METRICS_PLOTTING  } from '../modules/local/metrics/metrics.nf'
include { METRICS_PLOTTING as LAST_N_METRICS_PLOTTING } from '../modules/local/metrics/metrics.nf'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow MAIN {

    take:
    samplesheet

    main:

    // empty channel to store all software versions
    versions = Channel.empty()

    // channel holding information about run id, path to the run folder and a list of sample ids
    local_app_prepper_input = samplesheet
        .map{ it -> return [ it[6], it[7], it[1] ] }
        .groupTuple( by: [ 0, 1 ] )

    // channel holding information about run id, path to run folder and samplesheet
    run_folders = samplesheet
        .map{ it -> return [ it[6], it[7], it[8], [] ] }
        .unique()

    // MODULE: Prepare inputs.json for LocalApp
    LOCAL_APP_PREPPER (
        local_app_prepper_input
    )
    versions = versions.mix(LOCAL_APP_PREPPER.out.versions.first())

    // attach the json to the correct run folder information
    local_app_demultiplex_input = run_folders.join(LOCAL_APP_PREPPER.out.demultiplex)

    // MODULE: Run LocalApp demultiplex workflow
    LOCAL_APP_DEMULTIPLEX (
        local_app_demultiplex_input,
        file(params.tso500_resource_folder)
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
        file(params.tso500_resource_folder)
    )
    versions = versions.mix(LOCAL_APP_TSO500.out.versions.first())

    // merge all local app output folders in tuple and construct input channel for gather
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

    // MODULE: Run LocalApp Gather workflow
    GATHER (
        gather_input,
        file(params.tso500_resource_folder)
    )
    versions = versions.mix(GATHER.out.versions.first())

    // glob all MetricsOutput.tsv files and join with RunCompletionStatus.xml files for process_metrics_files
    metrics_output_tsv = channel.fromPath("${params.localapp_root_output_dir}/**_LocalApp_results/Results/MetricsOutput.tsv") // Channel: [ tsv ]
        .map { file ->
            def run_id = (file.toString() =~ /(\d{6}_\D{1,3}\d{5,6}(_RUO)?_\d{4}_\w{10})(_TSO_500)?_LocalApp_results/)[0][1]
            return [ run_id, file ]
        } // Channel: [ [ run_id, tsv ] ]
    if (params.decoy_run_completion_status_xml) {
        metrics_input_ch = metrics_output_tsv
            .map { run_id, file ->
                return [ run_id, file, params.decoy_run_completion_status_xml ]
            } // Channel: [ [ run_id, tsv, xml ] ]
            .collect(flat: false) // Channel: [ [ [ run_id, tsv, xml ], [ run_id, tsv, xml ], ... ] ]
            .transpose() // Channel: [ [ run_id, run_id, ... ], [ tsv, tsv, ... ], [ xml, xml, ... ] ]
    } else {
        run_completion_status_xml = channel.fromPath("${params.seq_data_root_output_dir}/*/RunCompletionStatus.xml")
            .map { file ->
                def run_id = (file.toString() =~ /(\d{6}_\D{1,3}\d{5,6}(_RUO)?_\d{4}_\w{10})/)[0][1]
                return [ run_id, file ]
            } // Channel: [ [ run_id, xml ] ]
        metrics_input_ch = metrics_output_tsv.join(run_completion_status_xml)
            .view()
            .collect(flat: false)
            .transpose()
            .collect(flat: false)
    }

    // MODULE: Run metrics plotting
    ALL_METRICS_PLOTTING(metrics_input_ch)

    //// Determine how many recent runs to plot
    //min_val = Math.min(params.n_runs, mp_run_ids.size())

    //if (min_val > 0) {
    //    // All runs: no plots
    //    ALL_METRICS_PLOTTING(
    //        mp_run_ids,
    //    )

    //    // Last N runs: allow plots
    //    def last_n_run_ids = mp_run_ids.subList(mp_run_ids.size() - min_val, mp_run_ids.size())

    //    LAST_N_METRICS_PLOTTING(
    //        last_n_run_ids,
    //    )

    // collate and save software versions
    softwareVersionsToYAML(versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'software_versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }
    emit:
    versions = versions

}

def get_sample_id(it) {
    def path_str = it.toString()
    def sample_id = path_str.substring(path_str.lastIndexOf('/') + 1).replace('tso500_', '').replace('.json', '')
    return sample_id
}
