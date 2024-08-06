using MTR

using RCall
using YAML
using .Preprocessing: get_cell_types, format_cell_types, get_cell_ontology_mapping,
                      get_cell_type_proportions, download_dataset,
                      add_pheno_column!
using OntologyLookup: search

data_path = ENV["DATA_DIR"]
data_file = "annonated_datasets.RData"
esets_description_file = "datasets.yaml"
raw_esets_dir = joinpath(data_path, "raw_esets_test")
annoted_esets_dir = joinpath(data_path, "annotated_esets")

# Create any of the directories that don't exist
for dir in [raw_esets_dir, annoted_esets_dir]
    if !isdir(dir)
        mkdir(dir)
    end
end

# Find out which datasets are required by reading data/datasets.yaml
datasets_desc = Preprocessing.read_datasets(esets_description_file)

# # To find out each eset, we get the file in the series of each dataset
# esets_desc = Dict([key => [value.file for value in val.series]
#                    for (key, val) in datasets_desc])

for dataset in values(datasets_desc)
    @info dataset
    # Check if all the files are downloaded
    if all([isfile(joinpath(raw_esets_dir, series.file)) for series in dataset.series])
        @info "All files for dataset $(dataset.id) have been downloaded"
    else
        @info "Downloading dataset $(dataset.id)"
        download_dataset(dataset)
    end
end

# Check if datasets have already are already downloaded 
if isfile(joinpath(data_path, data_file))
    @info "Annotated datasets have already been downloaded. Loading..."
else
    @info "Downloading and annotating datasets..."
    Preprocessing.run_r_preprocessing()
end

R"annonated_datasets <- readRDS(file.path($data_path, $data_file))"

# Load the datasets
annoted_datasets_R = @rget annonated_datasets
annoted_datasets = Dict([key => convert(ExpressionSet, val)
                         for (key, val) in annoted_datasets_R])

# Reference Datasets
ref_eset_dir = joinpath(data_path, "ref_esets")
ref_eset_ids = [:gse22886_gpl96, :gse22886_gpl97]
ref_eset_files = [joinpath(ref_eset_dir, "$id.RData")
                  for id in ref_eset_ids]

ref_esets = Dict{Symbol,ExpressionSet}()

pheno_col = "cell type:ch1"
ontology_col_name = "cell ontology:ch1"

for (ref_eset_id, ref_eset_file) in zip(ref_eset_ids, ref_eset_files)
    if isfile(ref_eset_file)
        @info "Reference dataset $ref_eset_id has already been preprocessed. Loading..."

        ref_eset_R = R" readRDS($ref_eset_file)"
        ref_eset = convert(ExpressionSet,
                           ref_eset_R)
        ref_esets[ref_eset_id] = ref_eset
    else
        @info "Preprocessing reference eset $ref_eset_id"
        eset = annoted_datasets[ref_eset_id]

        cell_types_raw = pData(eset)[!, pheno_col]
        cell_types = format_cell_types(cell_types_raw)
        mapping = get_cell_ontology_mapping(cell_types)

        add_pheno_column!(eset, ontology_col_name, [mapping[cell] for cell in cell_types])

        ref_esets[ref_eset_id] = eset

        ## Save the updated dataset
        # Create the directory if it doesn't exist
        if !isdir(ref_eset_dir)
            mkdir(ref_eset_dir)
        end

        save_eset(eset, ref_eset_file)
    end
end

ref_esets

# # Reference Datasets
# ref_eset_ids = [:gse22886_gpl96, :gse22886_gpl97]
# # ref_eset_ids = [:gse22886_gpl96]
# ref_esets = Dict([key => annoted_datasets[key]
#                   for key in ref_eset_ids])

# a = [pData(eset)[!, pheno_col] for eset in values(ref_esets)]
# b = [format_cell_types(cell_types) for cell_types in a]
# c = [get_cell_ontology_mapping(cell_types) for cell_types in b]

# # Update the eset with a new col, "cell ontology" to store the cell type with its ontology id
# for (e, cell_types, mapping) in zip(values(ref_esets), b, c)
#     add_pheno_column!(e, "cell ontology:ch1", [mapping[cell] for cell in cell_types])
# end

# # Save the updated datasets
# for (key, eset) in ref_esets

#     # Create the directory if it doesn't exist
#     if !isdir(joinpath(data_path, "ref_esets"))
#         mkdir(joinpath(data_path, "ref_esets"))
#     end

#     save_eset_path = joinpath(data_path, "ref_esets", "$key.RData")
#     save_eset(eset, save_eset_path)
# end

for (key, eset) in mixture_esets
end

# # Mixture Datasets
# mixtures_dataset_ids = [:gse65136_gpl10558, :gse65136_gpl96, :gse65136_gpl570]
# mixtures_datasets = Dict([key => annoted_datasets[key]
#                           for key in mixtures_dataset_ids])

# pheno_col = "flow cytometry cell subset proportions:ch1"

# a = [get_cell_types(eset, pheno_col) for eset in values(mixtures_datasets)]
# b = [format_cell_types(cell_types) for cell_types in a]
# c = [get_cell_ontology_mapping(cell_types) for cell_types in b]

# cell_proportions = Dict([id => get_cell_type_proportions(eset, pheno_col)
#                          for (id, eset) in mixtures_datasets])
