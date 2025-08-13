include("../../src/MTR.jl")

using .MTR
using .MTR.Preprocessing: get_cell_types, format_cell_types, get_cell_ontology_mapping,
                          get_cell_type_proportions, add_pheno_column!, read_datasets
using .MTR.Utils
using RCall
using JLD2
using DataFrames

data_path = ENV["DATA_DIR"]

esets_description_file = "datasets.yaml"
reference_pheno_col = "cell type:ch1"
mixture_pheno_col = "flow cytometry cell subset proportions:ch1"
ontology_fcol_name = "cell ontology:ch1"

preprocessed_esets_dir = joinpath(data_path, "preprocessed_esets")
# If the directory is empty, then we need to preprocess the datasets
if isempty(readdir(preprocessed_esets_dir))
    @error "The preprocessed datasets have not been found. Please preprocess the datasets first."
    @info "There is a R script that can be run to preprocess the datasets in the 'scripts' folder"
end

processed_esets_dir = joinpath(data_path, "processed_esets")
processed_esets_dir_contents = readdir(processed_esets_dir)
# Create the directory if it does not exist
if !isdir(processed_esets_dir)
    mkdir(processed_esets_dir)
end

# This script will behave depending on the information in the dataset descriptor file (datasets.yaml) 
# The file will tell us the reference, mixtures and synthetic datasets
# Read the docs for more information on the structure of the file
datasets_desc = read_datasets(esets_description_file)

## REFERENCE DATASETS
#
# For the reference datasets, we assume that each sample represent a single 
# cell type. The processing involves mapping the annotation with 
# the cell ontology and then adding the phenotype column
references_esets_desc = [series
                         for dataset in values(datasets_desc)
                         for series in dataset.series
                         if series.type == "reference"]
references_esets_ids = [join([series.id, series.platform], "-")
                        for series in references_esets_desc]

# Load the datasets
preprocessed_ref_esets_files = Dict([id => joinpath(preprocessed_esets_dir,
                                                    "$(id)_preprocessed.rds")
                                     for id in references_esets_ids])
preprocessed_ref_esets = Dict{String,ExpressionSet}()
for (id, file) in preprocessed_ref_esets_files
    if !isfile(file)
        @error "The file $file does not exist. Please preprocess the datasets first."
        break
    end

    R"eset <- readRDS($file)"
    eset = @rget eset
    preprocessed_ref_esets[id] = convert(ExpressionSet, eset)
end

processed_ref_esets_files = Dict([id => joinpath(processed_esets_dir,
                                                 "$(id)_processed.rds")
                                  for id in references_esets_ids])

for (ref_eset_id, ref_eset) in preprocessed_ref_esets
    ref_eset_file = processed_ref_esets_files[ref_eset_id]

    # Check if the dataset has already been preprocessed
    if isfile(ref_eset_file)
        @info "Reference dataset $ref_eset_id has already been processed. Skipping..."
        # ref_eset = load(ref_eset_file)
        continue
    end

    @info "Processing reference eset $ref_eset_id"
    eset = deepcopy(ref_eset)

    cell_types_raw = pData(eset)[!, reference_pheno_col]
    cell_types = format_cell_types(cell_types_raw)
    mapping = get_cell_ontology_mapping(cell_types)

    add_pheno_column!(eset, ontology_fcol_name, [mapping[cell] for cell in cell_types])

    # Save the eset to a file
    save_eset(eset, ref_eset_id, ref_eset_file)
end

## MIXTURE DATASETS
#
# For the mixtures, we assume that the samples are mixtures of the
# cell types. The processing is similiar as for reference but 
# requires a bit more parsing
mixtures_esets_desc = [series for dataset in values(datasets_desc)
                       for series in dataset.series if series.type == "mixture"]

mixtures_esets_ids = [join([series.id, series.platform], "-")
                      for series in mixtures_esets_desc]

preprocessed_mix_esets_files = Dict([id => joinpath(preprocessed_esets_dir,
                                                    "$(id)_preprocessed.rds")
                                     for id in mixtures_esets_ids])
preprocessed_mix_esets = Dict{String,ExpressionSet}()

for (id, file) in preprocessed_mix_esets_files
    if !isfile(file)
        @error "The file $file does not exist. Please preprocess the datasets first."
        break
    end

    R"eset <- readRDS($file)"
    eset = @rget eset
    preprocessed_mix_esets[id] = convert(ExpressionSet, eset)
end

processed_mix_esets_files = Dict([id => joinpath(processed_esets_dir,
                                                 "$(id)_processed.jld2")
                                  for id in mixtures_esets_ids])

record_cell_proportions = Dict{String,Any}()

temp_cell_proportions = Dict{String,Any}()
temp_mapping = Dict{String,Any}()


# ADD SINk

for (mix_eset_id, mix_eset) in preprocessed_mix_esets
    mix_eset_file = processed_mix_esets_files[mix_eset_id]

    # Check if the dataset has already been processed
    if isfile(mix_eset_file)
        @info "Mixture dataset $mix_eset_id has already been processed. Skipping..."
        continue
    end

    @info "Processing mixture eset $mix_eset_id"
    eset = deepcopy(mix_eset)

    cell_proportions = get_cell_type_proportions(eset, mixture_pheno_col)
    record_cell_proportions[mix_eset_id] = deepcopy(cell_proportions)

    cell_types_raw = names(cell_proportions)

    for (cell_type) in cell_types_raw
        if cell_type == "sample_id"
            continue
        end

        formated_cell_type = format_cell_types([cell_type])
        mapping = get_cell_ontology_mapping(formated_cell_type)

        if (ismissing(mapping[first(formated_cell_type)]))
            @warn "The cell type $(first(formated_cell_type)) has not been mapped to the cell ontology"
            continue
        end

        # Rename the col with the cell ontology
        # Fist check if the col already exist, and if so combine them by adding the values
        if haskey(temp_cell_proportions, mix_eset_id)
            # @info first(formated_cell_type), names(temp_cell_proportions[mix_eset_id])
            if mapping[first(formated_cell_type)] in
               names(temp_cell_proportions[mix_eset_id])
                @info "Combining cell types $(first(formated_cell_type)) and $(mapping[first(formated_cell_type)])"
                temp_cell_proportions[mix_eset_id][!, mapping[first(formated_cell_type)]] += cell_proportions[!,
                                                                                                              cell_type]
                # Remove the cols that have been combined
                select!(temp_cell_proportions[mix_eset_id], Not(cell_type))
            else
                rename!(cell_proportions,
                        cell_type => mapping[first(formated_cell_type)])
                # temp_cell_proportions[mix_eset_id][!, mapping[first(formated_cell_type)]] = cell_proportions[!,
                #  cell_type]
            end
        else
            rename!(cell_proportions,
                    cell_type => mapping[first(formated_cell_type)])
            temp_cell_proportions[mix_eset_id] = cell_proportions
        end

        temp_mapping[first(formated_cell_type)] = mapping[first(formated_cell_type)]
    end

    # Save the updated dataset
    save_eset(eset, mix_eset_id, mix_eset_file)

    # Save the cell proportions
    save(split(mix_eset_file, ".")[1] * "_cell_proportions.jld2", "cell_proportions",
         temp_cell_proportions[mix_eset_id])
end

### Graph construction
preprocessed_ref_esets_pairings_files = Dict([id => joinpath(processed_esets_dir,
                                                             "$(id)_processed_pairings.rds")
                                              for id in references_esets_ids])

R"ref_eset_pairings <- lapply($preprocessed_ref_esets_pairings_files, function(x) readRDS(x))"
ref_eset_pairings_R = @rget ref_eset_pairings

ref_eset_pairings = Dict{Symbol,Dict{Symbol,Vector{String}}}()

# Convert to Dict{Symbol, String}
for (index, pairing_tuple) in enumerate(ref_eset_pairings_R)
    key, pairing = pairing_tuple
    ref_eset_pairings[key] = Dict{Symbol,Vector{String}}(pairing)
end

using OntologyLookup
include("../../src/graphs/ontology_tree.jl")

onto = "cl"
base_term_iri = "http://purl.obolibrary.org/obo/CL_0000988"  # Hematopoietic cell
base_term = onto_term(onto, base_term_iri)

pairings = Dict{Symbol,Dict{Term,Vector{String}}}()

onto_trees = Dict{Symbol,OntologyTree}()

# Get the required terms from the keys of the pairings
for (key, pairing) in ref_eset_pairings
    pairings[key] = Dict{Term,Vector{String}}()
    required_terms_ids = collect(keys(ref_eset_pairings[key]))

    required_terms = Term[]
    for term_id in sort(required_terms_ids)
        terms = onto_terms(onto; id=String(term_id))
        if length(terms) == 0
            @warn "No terms found for id: $term_id"
            continue
        end

        term = first(terms)
        push!(required_terms, term[2])

        # Add the term to the pairings object
        pairings[key][term[2]] = ref_eset_pairings[key][term_id]
    end

    onto_trees[key] = OntologyTree(base_term, required_terms; max_parent_limit=20)
end

sort([x.label for x in onto_trees[Symbol("GSE22886-GPL96")].required_terms])

# test_g = MetaGraphs.MetaDiGraph()
# add_vertex!(test_g)
# collect(vertices(test_g))
# set_prop!(test_g, 1, :term, base_term)
# test_g.vprops[1][:term]

for (key, onto_tree) in onto_trees
    populate!(onto_tree)

    for (term, genes) in pairings[key]
        add_genes!(onto_tree, genes)
    end

    connect_term_genes!(onto_tree, pairings[key])
end

using LightXML

g = onto_trees[Symbol("GSE22886-GPL96")].graph

export_to_graphxml(g, "graph.xml")

## Now that we have  reference graphs we can construct a graph for the mixtures
## Note that for each mixtures datasets, the graph will be the same but the following attributes will be different
## - The gene expression for each gene -> this the observation
## - The cell type proportions  -> this is the label to predict

## For the IDs, they will be construct by combining the following:
## - The reference dataset ID
## - The mixture dataset ID
## - The sample ID

mixtures_graphs = Dict{Symbol,OntologyTree}()

processed_mix_esets = merge([load(file) for file in values(processed_mix_esets_files)]...)

df = first(processed_mix_cell_proportions)

processed_mix_cell_proportions = Dict([id => load(split(file, ".")[1] *
                                                  "_cell_proportions.jld2")["cell_proportions"]
                                       for (id, file) in processed_mix_esets_files])

processed_mix_cell_proportions["GSE65136-GPL570"]

max_samples = 10

for (key, onto_tree) in onto_trees
    for (eset_id, eset) in processed_mix_esets
        cell_proportions = processed_mix_cell_proportions[eset_id]

        for sample_id in sampleNames(eset)
            @info "Processing sample: $sample_id"
            mix_tree = deepcopy(onto_tree)

            gx = get_gene_expression(eset, onto_tree)
            gx_sample = gx[!, sample_id]
            gx_sample_with_id::Vector{Tuple{String,Float64}} = [(id, gx)
                                                                for (gx, id) in
                                                                    zip(gx_sample,
                                                                        gx[!,
                                                                           "feature_names"])]
            add_gene_expression!(mix_tree, gx_sample_with_id)

            sample_id_index_in_cell_proportions = findfirst(x -> x == sample_id,
                                                            cell_proportions[!,
                                                                             "sample_id"])
            if isnothing(sample_id_index_in_cell_proportions)
                @warn "Sample ID: $sample_id not found in the cell proportions. Skipping."
                continue
            end

            cur_cell_proportions = cell_proportions[sample_id_index_in_cell_proportions,
                                                    :]
            cur_cell_proportions = [(cell, proportion)
                                    for (cell, proportion) in
                                        zip(names(cell_proportions),
                                            cur_cell_proportions)
                                    if cell != "sample_id"]
            cur_cell_proportions = [(replace(cell, "_" => ":"), gx)
                                    for (cell, gx) in cur_cell_proportions]

            add_cell_proportions!(mix_tree, cur_cell_proportions)

            propagate_cell_proportions!(mix_tree)

            # Ref+Mix+Sample id 
            mix_tree_id = Symbol("$(key)_$(eset_id)_$(sample_id)")
            mixtures_graphs[mix_tree_id] = mix_tree
        end
    end
end

function get_gene_expression(eset::ExpressionSet, onto_tree::OntologyTree)
    graph = get_graph(onto_tree)
    expression = exprs(eset)

    # Find out what genes are present in the ontology tree
    vertices_with_genes = [v_index
                           for (v_index, v_props) in graph.vprops
                           if haskey(v_props, :gene_id)]
    genes = [get_prop(onto_tree.graph, v_index, :gene_id)
             for v_index in vertices_with_genes]

    genes_ids = fData(eset)[!, "ensembl_id"]
    gene_present_indices = []

    for gene in genes
        if gene ∉ genes_ids
            # @warn "Gene: $gene not found in the expression dataset. Skipping."
            continue
        end
        # Find the index of the gene in the expression dataset
        gene_indx = findfirst(x -> x == gene, genes_ids)
        push!(gene_present_indices, gene_indx)
    end

    # Rename the column feature name with the ensembl ids
    expression[!, "feature_names"] = genes_ids

    return expression[gene_present_indices, :]
end

function add_gene_expression!(onto_tree::OntologyTree,
                              gene_expression::Vector{Tuple{String,Float64}})
    graph = get_graph(onto_tree)

    for gene_id_expression in gene_expression
        # Find the index of the gene in the graph
        index = get_vertex_number_by_gene(graph, gene_id_expression[1])
        worked = set_gene_props!(onto_tree.graph, gene_id_expression, index)
        # if !worked
        #     @warn "Error adding gene: $(gene_id_expression[1]) to the graph. Skipping."
        # end
    end

    # After setting all the expression values, we can set the expression of all the remaining genes to 0
    # NOTE that this is not the best way to handle this, but it is a start
    for vertex in vertices(graph)
        if !haskey(graph.vprops[vertex], :gene_id)
            continue
        end

        if graph.vprops[vertex][:type] == :gene &&
           (!haskey(graph.vprops[vertex], :expression) ||
            ismissing(graph.vprops[vertex][:expression]))
            set_prop!(graph, vertex, :expression, 0.0)
        end
    end

    return nothing
end

function add_cell_proportions!(onto_tree::OntologyTree,
                               cell_proportions::Vector{Tuple{String,Float64}})
    graph = get_graph(onto_tree)

    for (cell_type, proportion) in cell_proportions
        term_index = get_vertex_number_by_term_id(graph, cell_type)
        if ismissing(term_index)
            @warn "Term: $cell_type not found in the graph. Skipping."
            continue
        end

        worked = set_prop!(graph, term_index, :proportion, proportion)
        if !worked
            @warn "Error adding proportion: $proportion to term: $cell_type. Skipping."
        end
    end

    return nothing
end

# Propagate the cell proportions to the parents
# The rationale is that if a cell type has a proportion,
# then all its parents should have the same proportion
# This is because the cell type is a subset of the parent
# As such, if a cell type has multiple children, then the proportion
# of the parent should be the sum of the children

function propagate_cell_proportions!(onto_tree::OntologyTree)
    graph = get_graph(onto_tree)

    proportions_to_propagate = [v_index
                                for (v_index, v_props) in graph.vprops
                                if haskey(v_props, :proportion)]
    terms_to_propagate = [get_prop(graph, vertex, :term).label
                          for vertex in proportions_to_propagate]
    @info "Propagating proportions for terms: $(terms_to_propagate)"

    for vertex in proportions_to_propagate
        @info "Propagating proportion for term: $(get_prop(graph, vertex, :term).label)"
        if graph.vprops[vertex][:type] !== :term
            continue
        end
        if !haskey(graph.vprops[vertex], :proportion)
            continue
        end

        parent_index = get_parent(graph, vertex)
        if isnothing(parent_index)
            continue
        end

        proportion = get_prop(graph, vertex, :proportion)

        if !haskey(graph.vprops[parent_index], :proportion)
            # @info "Parent does not have a proportion. Setting it to: $proportion"
            set_prop!(graph, parent_index, :proportion, proportion)
        else
            parent_prop = get_prop(graph, parent_index, :proportion)

            set_prop!(graph, parent_index, :proportion,
                      parent_prop + proportion)
            # @info "Parent already has a proportion: $parent_prop. Adding: $proportion"
        end

        @info "Propagating proportion: $proportion to parent: $(get_prop(graph, parent_index, :term).label)"
        propagate_proportion_to_parent!(onto_tree, parent_index, proportion)
    end

    @info "Proportion propagation done."
    @info "Setting the proportion of all the remaining cell_type cells to 0"

    # Then we can set the proportion of all the remaining cell_type cells to 0
    for vertex in vertices(graph)
        if haskey(graph.vprops[vertex], :proportion)
            continue
        end

        if graph.vprops[vertex][:type] == :term
            # @info "Setting proportion of cell: $(get_prop(graph, vertex, :term).label) to 0"
            set_prop!(graph, vertex, :proportion, 0.0)
        end
    end
end

function propagate_proportion_to_parent!(onto_tree::OntologyTree, vertex::Int,
                                         proportion::Float64)
    graph = get_graph(onto_tree)

    if graph.vprops[vertex][:type] !== :term
        return nothing
    end
    vertex_term = get_prop(graph, vertex, :term)
    # @info "Propagating proportion: $proportion for term: $(vertex_term.label)"

    parent_index = get_parent(graph, vertex)
    if isnothing(parent_index)
        return nothing
    end

    parent_term = get_prop(graph, parent_index, :term)
    # @info "To parent: $(parent_term.label)"

    if !haskey(graph.vprops[parent_index], :proportion)
        # @info "Parent does not have a proportion. Setting it to: $proportion"
        set_prop!(graph, parent_index, :proportion, proportion)
    else
        parent_prop = get_prop(graph, parent_index, :proportion)

        set_prop!(graph, parent_index, :proportion,
                  parent_prop + proportion)
        # @info "Parent already has a proportion: $parent_prop. Adding: $proportion"
    end

    propagate_proportion_to_parent!(onto_tree, parent_index, proportion)

    return nothing
end

record_cell_proportions

test_propag = deepcopy(mixtures_graphs[Symbol("GSE22886-GPL97_GSE65136-GPL10558_GSM1587809")])
# [x[:type] for x in values(test_propag.graph.vprops) if haskey(x, :type) && x[:type] == :term]
propagate_cell_proportions!(test_propag)

test_graph = deepcopy(first(mixtures_graphs)[2])

export_to_graphxml(test_graph.graph, "propagated_graph.xml")

# [d[:expression] for d in values(test_graph.graph.vprops) if haskey(d, :expression)]

# We need a functon to establish what are the parent of a given vertex
# We can do this by looking at the edges that have the vertex as the destination
function get_parent(graph::MetaGraphs.MetaDiGraph, vertex::Int)
    for edge in edges(graph)
        if src(edge) == vertex
            return dst(edge)
        end
    end

    return nothing
end

eset = preprocessed_mix_esets["GSE65136-GPL10558"]
onto_tree = deepcopy(onto_trees[Symbol("GSE22886-GPL97")])

gx = get_gene_expression(preprocessed_mix_esets["GSE65136-GPL10558"],
                         onto_trees[Symbol("GSE22886-GPL97")])

sample_id = "GSM1587800"
gx_sample = gx[!, sample_id]
gx_sample_with_id::Vector{Tuple{String,Float64}} = [(id, gx)
                                                    for (gx, id) in zip(gx_sample,
                                                                        gx[!, "feature_names"])]
add_gene_expression!(onto_tree, gx_sample_with_id)

sample_id_index_in_cell_proportions = findfirst(x -> x == sample_id,
                                                processed_mix_cell_proportions["GSE65136-GPL10558"][!,
                                                                                                    "sample_id"])
cp_raw = processed_mix_cell_proportions["GSE65136-GPL10558"][sample_id_index_in_cell_proportions,
                                                             :]
cp = [(cell, proportion)
      for (cell, proportion) in zip(names(cp_raw), cp_raw) if cell != "sample_id"]
cp_post = [(replace(cell, "_" => ":"), gx) for (cell, gx) in cp]

add_cell_proportions!(onto_tree, cp_post)

get_vertex_number_by_term_id(onto_tree.graph, "CL_0000576")

vertex_with_term_prop = [v_index
                         for (v_index, v_props) in onto_tree.graph.vprops
                         if haskey(v_props, :term)]
[get_prop(onto_tree.graph, v, :term).obo_id for v in vertex_with_term_prop]

mixtures_graphs[mix_eset_id] = mix_graphs

sample_onto_trees_dir = joinpath(data_path, "sample_onto_trees")
if !isdir(sample_onto_trees_dir)
    mkdir(sample_onto_trees_dir)
end

for (key, onto_tree) in mixtures_graphs
    save(joinpath(sample_onto_trees_dir, "$(key)_onto_tree.jld2"), "onto_tree", onto_tree)
end
