# This script is for creating a base graph from a reference dataset. The reference dataset is a processed Eset from GEO. The graph is created by using the cell type proportions as the edge weights. The graph is then saved as a GraphML file. 
# Assumptions: 
# - The reference dataset is already processed and saved as an RDS file.
# - The reference dataset has the following columns: 
#       cell ontology:ch1
#       cell type proportion
#       feature_names

# Load the necessary packages
using JLD2
using DataFrames
using Statistics
using Random
using MetaGraphs
using OntoLinker

# Load the custom modules
using OntologyLookup

# Load the configuration file
include("./reference_graph_config.jl")

include("../../src/utils/graph.jl")
include("../../src/utils/io.jl")

# Read eset from file
# We switch to R to generate a set of significant genes for each cell type
# For more information, see the get_cell_type_marker_genes function in the R script (reference_genes.r)
R"""
source($r_script_path) 
eset <- readRDS($eset_file)
pairings <- get_cell_type_marker_genes(eset)
"""

pairings_R = @rget pairings

# Convert the pairings to a Julia dictionary
ref_eset_pairings = Dict{Symbol,Vector{String}}()
for (key, value) in pairings_R
    ref_eset_pairings[key] = value
end

# test_genes = ref_eset_pairings[:CL_0000236]
iris = [iri_from_id(id) for id in keys(ref_eset_pairings)]
graph = OntoLinker.generate_graph(iris, OntoLinker.Config())

ref_graph = create_reference_graph(ref_eset_pairings)

# Save the graph as a GraphML file
# graphml_file = joinpath(data_path, "reference_graph.graphml")
# export_to_graphxml(ref_graph.graph, graphml_file)

# Save the ontology_tree as a JLD2 file
jld2_file = joinpath(data_path, "reference_graph.jld2")
save(jld2_file, "graph", ref_graph)

function create_reference_graph(pairings::Dict{Symbol,Vector{String}};
                                onto="cl",
                                base_term_iri="http://purl.obolibrary.org/obo/CL_0000000")::OntologyTree
    base_term = onto_term(onto, base_term_iri)
    required_terms_ids = collect(keys(pairings))

    # Required nodes for the graph
    # Here for now we are going to use the first nodes to be Terms (specificaly CL terms)
    term_paired_nodes = Dict{Term,Vector{String}}()
    required_terms = Term[]
    for term_id in sort(required_terms_ids)
        term = onto_term(onto, iri_from_id(term_id))
        if ismissing(term)
            @warn "Term not found: $term_id"
            continue
        end
        push!(required_terms, term)
        # Add the term to the pairings object
        term_paired_nodes[term] = ref_eset_pairings[term_id]
    end

    onto_tree = OntologyTree(base_term, required_terms; max_parent_limit=20)

    populate!(onto_tree)

    for (_, genes) in term_paired_nodes
        add_genes!(onto_tree, genes)
    end

    connect_term_genes!(onto_tree, term_paired_nodes)

    return onto_tree
end

function iri_from_id(id::String)::String
    base_url = "http://purl.obolibrary.org/obo/"
    # If the id is in the form with the semi-colon
    # Then we need to replace it with the underscore to get the IRI url 
    if occursin(":", id)
        return "$base_url$(replace(id, ':' => '_'))"
    else
        return "$base_url$id"
    end
end

function iri_from_id(id::Symbol)::String
    return iri_from_id(string(id))
end