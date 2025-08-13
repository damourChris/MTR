
nextflow.enable.dsl = 2

// The raw_eset should contained all the eset that will be used to train the model
// Each file in the raw_eset should be a eset object
// Each file will be processed to get the ensembl ids, and the proportions of the different cell types
// It will be sorted into the appropriate channel depending on the config file
raw_esets = Channel.fromPath("data/input/raw_esets/*")

// The reference_esets should contain the esets with purified cell type proportions
reference_esets = Channel.fromPath("data/input/reference_esets/*")

// In the preprocessing step, we will generate referece graphs 
//  - These are generated from the reference_esets
graphs = Channel.fromPath("data/graphs/*")
train_data = Channel.fromPath("data/input/train_data/*")

// The testing_esets should contain the esets that will be used to test the model
// Note that the testing_esets should not be used to train the model 
//          i.e the model will never see the testing_esets
testing_esets = Channel.fromPath("data/input/test_esets/*")
hetero_gnn_files = Channel.fromPath("data/input/het_gnn/*")

results_files = Channel.fromPath("data/results/*")
reports_files = Channel.fromPath("data/reports/*")

config_files = Channel.fromPath("data/configs/*")

process map_to_ids {
    input: 
        file eset
    output:
        file "${eset.baseName}.ensembl"
    
    script:
    """
    map_to_ensembl ${eset} -o ${eset.baseName}.ensembl.jld2
    """
}

// process get_proportions {
//     input:
//         file eset from ensembl_files
//     output:
//         file("${eset.baseName}.proportions", "${eset.baseName}.proportions.md5") into proportions_files
    
//     script:
//     """
//     Rscript ${script_dir}/get_proportions.R ${eset}
//     """
// }

// process generate_synthetic_datasets {
//     input: 
//         file eset from eset_files
//     output:
//         file("${eset.baseName}.synthetic.jld2", "${eset.baseName}.synthetic.toml") into synthetic_files
//     script:
//     """
//     sme -i ${eset} -o ${eset.baseName}.synthetic.jld2 -c ${config_file}
//     """
// }

// process generate_training_data {
//     input: 
//         file eset from synthetic_files
//     output:
//         file("${eset.baseName}.train_data.jld2", "${eset.baseName}.train_data.toml") into train_data
//     script:
//     """
//     julia scripts/generate_training_data.jl -i ${eset} -o ${eset.baseName}.train_data.jld2
//     """
// }

// process generate_reference_graphs {
//     input: 
//         eset from reference_esets
//     output:
//         file("${eset.baseName}.graphml") into graphs
//     script:
//     """
//     ontolinker ${eset} -o ${eset.baseName}.graph.jld2
//     """
// }

// process train_model {
//     input: 
//         file train_data from train_data
//     output:
//         file("${train_data.baseName}.model.jld2", "${train_data.baseName}.model.toml") into model_files
//     script:
//     """
//     julia scripts/train_model.jl -i ${train_data} -o ${train_data.baseName}.model.jld2
//     """
// }

// process generate_reports {
//     input: 
//         file eset from results_files
//     output:
//         file("${eset.baseName}.report.html", "${eset.baseName}.report.html.md5") into reports_files
//     script:
//     """
//     julia scripts/generate_reports.jl -i ${eset} -o ${eset.baseName}.report.html
//     """
// }

workflow {
    map_to_ids(raw_esets)
}