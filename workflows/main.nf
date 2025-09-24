/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { GATHER_RESULTS_WORKFLOW                            } from '../modules/local/acadia_500_wdl_workflow/main'
include { TSO500_WORKFLOW as TSO500_WORKFLOW_DEMULTIPLEX     } from '../modules/local/acadia_500_wdl_workflow/main'
include { TSO500_WORKFLOW                                    } from '../modules/local/acadia_500_wdl_workflow/main'
include { LOCAL_APP_PREPPER                                  } from '../modules/local/local_app_prepper/main'
include { PROCESS_METRICS_FILES as PROCESS_METRICS_FILES_ALL } from '../modules/local/process_metrics_files/main'
include { PROCESS_METRICS_FILES as PROCESS_METRICS_FILES_N   } from '../modules/local/process_metrics_files/main'
include { softwareVersionsToYAML                             } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { paramsSummaryMap                                   } from 'plugin/nf-schema'
include { samplesheetToList                                  } from 'plugin/nf-schema'
include { validateParameters                                 } from 'plugin/nf-schema'

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

    /*
        MODULE: LocalApp prepper
    */

    // prepare channel from samplesheet holding information about run id, path to the run folder and a list of sample ids
    local_app_prepper_input = samplesheet // Channel: [ [ dataset_id, sample_id, molecule, sample_type, tumor_site, tumor_content, run_id, run, samplesheet, barcode ] ]
        .map{ it -> return [ it[6], it[7], it[1] ] } // Channel: [ [ run_id, run, sample_id ] ]
        .groupTuple( by: [ 0, 1 ] ) // Channel: [ [ run_id, run, [ sample_id, sample_id, ... ] ] ]

    // run process
    LOCAL_APP_PREPPER (
        local_app_prepper_input
    )

    // add versions to versions channel
    versions = versions.mix(LOCAL_APP_PREPPER.out.versions.first())

    /*
        MODULE: TSO500 demultiplex workflow (LocalApp)
    */

    // prepare channel from samplesheet holding information about run id, path to run folder and samplesheet
    run_folders = samplesheet // Channel: [ [ dataset_id, sample_id, molecule, sample_type, tumor_site, tumor_content, run_id, run, samplesheet, barcode ] ]
        .map{ it -> return [ it[6], it[7], it[8], [] ] } // Channel: [ [ run_id, run, samplesheet, [] ] ]
        .unique() // Channel: [ [ run_id, run, samplesheet, [] ] ]

    // attach the json to the correct run folder information
    tso500_workflow_demultiplex_input = run_folders // Channel: [ [ run_id, run, samplesheet, [] ] ]
        .join(LOCAL_APP_PREPPER.out.demultiplex) // Channel: [ [ run_id, run, samplesheet, [], json ] ]

    // run process
    TSO500_WORKFLOW_DEMULTIPLEX (
        tso500_workflow_demultiplex_input,
        file(params.tso500_resources_directory)
    )

    // add versions to versions channel
    versions = versions.mix(TSO500_WORKFLOW_DEMULTIPLEX.out.versions.first())

    /*
        MODULE: TSO500 workflow (LocalApp)
    */

    // prepare channel for each sample
    tso500_workflow_input = run_folders // Channel: [ [ run_id, run, samplesheet, [] ] ]
        .join(TSO500_WORKFLOW_DEMULTIPLEX.out.results) // Channel: [ [ run_id, run, samplesheet, [], results ] ]
        .combine(LOCAL_APP_PREPPER.out.tso500.transpose(), by: 0) // Channel: [ [ run_id, run, samplesheet, [], results, json ] ]
        .map{ it -> return [ get_sample_id(it[5]), it[1], it[2], it[4], it[5] ] } // Channel: [ [ sample_id, run, samplesheet, results, json ] ]

    // run process
    TSO500_WORKFLOW (
        tso500_workflow_input,
        file(params.tso500_resources_directory)
    )

    // add versions to versions channel
    versions = versions.mix(TSO500_WORKFLOW.out.versions.first())

    /*
        MODULE: Gather results workflow (LocalApp)
    */

    // merge all LocalApp output directories in tuple
    results_directories = LOCAL_APP_PREPPER.out.tso500 // Channel: [ run_id, [ json ] ]
        .transpose() // Channel: [ [ run_id, json ] ]
        .map{ it -> return [ get_sample_id(it[1]), it[0] ] } // Channel: [ [ sample_id, run_id ] ]
        .join(TSO500_WORKFLOW.out.results) // Channel: [ [ sample_id, run_id, results ] ]
        .map{ it -> return [ it[1], it[2] ] } // Channel: [ [ run_id, results ] ]
        .concat(TSO500_WORKFLOW_DEMULTIPLEX.out.results) // Channel: [ [ run_id, results ] ]
        .groupTuple() // Channel: [ [ run_id, [ results, results, ... ] ] ]

    // prepare channel holding run directories, results directories and gather json
    gather_results_workflow_input = run_folders // Channel: [ [ run_id, run, samplesheet, [] ] ]
        .map{ it -> return [ it[0], it[1], it[2] ] } // Channel: [ [ run_id, run, samplesheet ] ]
        .join(results_directories) // Channel: [ [ run_id, run, samplesheet, [ results, results, ... ] ] ]
        .join(LOCAL_APP_PREPPER.out.gather) // Channel: [ [ run_id, run, samplesheet, [ results, results, ... ], json ] ]

    // run process
    GATHER_RESULTS_WORKFLOW (
        gather_results_workflow_input,
        file(params.tso500_resources_directory)
    )

    // add versions to versions channel
    versions = versions.mix(GATHER_RESULTS_WORKFLOW.out.versions.first())

    /*
        MODULE: Process metrics files (All runs)
    */

    // gather all relevant MetricsOutput.tsv files
    metrics_output_tsv = channel.fromPath("${params.tso500_root_output_directory}/**_LocalApp_results/Results/MetricsOutput.tsv") // Channel: [ tsv ]
        .map { file ->
            def run_id = (file.toString() =~ /(\d{6}_\D{1,3}\d{5,6}(_RUO)?_\d{4}_\w{10})(_TSO_500)?_LocalApp_results/)[0][1]
            return [ run_id, file ]
        } // Channel: [ [ run_id, tsv ] ]

    // join with (decoy) RunCompletionStatus.xml with MetricsOutput.tsv
    if (params.decoy_run_completion_status_xml) {
        metrics_output_tsv_run_completion_status_xml = metrics_output_tsv // Channel: [ [ run_id, tsv ] ]
            .map { run_id, file -> return [ run_id, file, params.decoy_run_completion_status_xml ] } // Channel: [ [ run_id, tsv, xml ] ]
    } else {
        run_completion_status_xml = channel.fromPath("${params.raw_data_root_directory}/*/RunCompletionStatus.xml") // Channel: [ xml ]
            .map { file ->
                def run_id = (file.toString() =~ /(\d{6}_\D{1,3}\d{5,6}(_RUO)?_\d{4}_\w{10})/)[0][1]
                return [ run_id, file ]
            } // Channel: [ [ run_id, xml ] ]
        metrics_output_tsv_run_completion_status_xml = metrics_output_tsv // Channel: [ [ run_id, tsv ] ]
            .join(run_completion_status_xml) // Channel: [ [ run_id, tsv, xml ] ]
    }

    // sort MetricsOutput.tsv and RunCompletionStatus.xml by run_id descending
    metrics_output_tsv_run_completion_status_xml_sorted = metrics_output_tsv_run_completion_status_xml
        .toSortedList{ a, b -> b[0] <=> a[0] } // Channel: [ [ [ run_id, tsv, xml ], [ run_id, tsv, xml ], ... ] ] sorted by run_id descending

    // prepare channel holding list of run_ids, list of MetricsOutput.tsv files and list of RunCompletionStatus.xml files
    process_metrics_files_all_input = metrics_output_tsv_run_completion_status_xml_sorted // Channel: [ [ run_id, tsv, xml ], [run_id, tsv, xml], ... ]
        .transpose() // Channel: [ [ run_id, run_id, ... ], [ tsv, tsv, ... ], [ xml, xml, ... ] ]
        .collect(flat: false) // Channel: [ [ [ run_id, run_id, ... ], [ tsv, tsv, ... ], [ xml, xml, ... ] ] ]

    // run process
    PROCESS_METRICS_FILES_ALL(process_metrics_files_all_input)

    // add versions to versions channel
    versions = versions.mix(PROCESS_METRICS_FILES_ALL.out.versions.first())

    /*
        MODULE: Process metrics files (Last N runs)
    */

    // calculate index in metrics tuples
    idx = params.process_metrics_files_n - 1
    metrics_output_tsv.count().map{ it ->
        if( it < params.process_metrics_files_n ) {
            idx = it - 1 // the scope in here is weird as it is the same as in the next mapping function so idx is set correctly but printing idx outside will show the original value
        }
    }
    // select last n runs
    process_metrics_files_n_input = process_metrics_files_all_input // Channel: [ [ [ run_id, run_id, ... ], [ tsv, tsv, ... ], [ xml, xml, ... ] ] ]
        .map { it -> return [ it[0][0..idx], it[1][0..idx], it[2][0..idx] ] } // Channel: [ [ [ run_id, run_id, ... ], [ tsv, tsv, ... ], [ xml, xml, ... ] ] ] select last n items

    // run process
    PROCESS_METRICS_FILES_N(process_metrics_files_n_input)

    // add versions to versions channel
    versions = versions.mix(PROCESS_METRICS_FILES_N.out.versions.first())

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
