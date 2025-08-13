module GraphsQuery

using Graphs
using GraphRecipes
using MetaGraphs
using OntologyLookup
using Plots
using RCall

include("ontology_tree.jl")

data_path = ENV["DATA_DIR"]
reference_datasets_pairings_files = readdir(joinpath(data_path,
                                                     "reference_datasets_pairings");
                                            join=true)

R"reference_datasets_pairings <- lapply($reference_datasets_pairings_files, function(x) readRDS(x))"
reference_datasets_pairings_R = @rget reference_datasets_pairings

reference_datasets_pairings = Dict{Symbol,Dict{Symbol,Vector{String}}}()

exprs(reference_datasets[:gse22886_gpl97])

# Convert to Dict{Symbol, String}
for (index, pairing) in enumerate(reference_datasets_pairings_R)
    key = collect(keys(reference_datasets))[index]
    reference_datasets_pairings[key] = Dict{Symbol,Vector{String}}(pairing)
end

onto = "cl"
base_term_iri = "http://purl.obolibrary.org/obo/CL_0000988"  # Hematopoietic cell
base_term = onto_term(onto, base_term_iri)

pairings = Dict{Symbol,Dict{Term,Vector{String}}}()

onto_trees = Dict{Symbol,OntologyTree}()

# Get the required terms from the keys of the pairings
for (key, pairing) in reference_datasets_pairings
    pairings[key] = Dict{Term,Vector{String}}()
    required_terms_ids = collect(keys(reference_datasets_pairings[key]))

    required_terms = Term[]
    for term_id in required_terms_ids
        terms = onto_terms(onto; id=String(term_id))
        if length(terms) == 0
            @warn "No terms found for id: $term_id"
            continue
        end

        term = first(terms)
        push!(required_terms, term[2])

        # Add the term to the pairings object
        pairings[key][term[2]] = reference_datasets_pairings[key][term_id]
    end

    onto_trees[key] = OntologyTree(base_term, required_terms)
end

for (key, onto_tree) in onto_trees
    populate!(onto_tree)

    add_genes!(onto_tree, pairings[key])

    connect_term_genes!(onto_tree, pairings[key])
end

Utils.plot_graph_with_labels(onto_trees[:gse22886_gpl96].graph)

using JLD2

tree = load("src/data/onto_trees/GSE22886-GPL96_onto_tree.jld2")
graph = tree["onto_tree"].graph

connect_genes!(graph)

end # module

# for (index, term) in enumerate(required_terms)
#     add_vertex!(graph)
#     set_term_props!(graph, term, index)
# end

# for (index, node) in enumerate(required_terms)
#     check_parent_limit = CHECK_PARENT_LIMIT_MAX

#     # While the parents list doesnt contain the base node, keep getting the hiercahical parents
#     cur_node = node # Start with the current node
#     @info "Currently on node: $(cur_node.label)"
#     while check_parent_limit > 0
#         @info "Current node is: $(cur_node.label)"
#         @info "Current parent limit is: $check_parent_limit"
#         if cur_node == base_term
#             @info "Reached base node: $(base_term.label). Stopping."
#             break
#         end

#         cur_node_parent = get_hierarchical_parent(cur_node; preferred_parent=base_term)
#         cur_node_index = get_vertex_number_by_term_id(graph, cur_node.obo_id)

#         if ismissing(cur_node)
#             @warn "Error fetching parents for node: $cur_node. Skipping."
#             break
#         end

#         # Check if the parent is already in the graph 
#         if is_term_in_graph(graph, cur_node_parent)
#             @info "Parent: $(cur_node_parent.label) already in graph. Stopping."
#             existing_parent_index = get_vertex_number_by_term_id(graph,
#                                                                  cur_node_parent.obo_id)
#             add_edge!(graph, cur_node_index, existing_parent_index)
#             break
#         end

#         @info "Adding parent: $(cur_node_parent.label)"
#         add_vertex!(graph)

#         # Connect the parent to the current node
#         cur_parent_index = nv(graph)
#         add_edge!(graph, cur_node_index, cur_parent_index)
#         set_term_props!(graph, cur_node_parent, cur_parent_index)

#         check_parent_limit -= 1
#         cur_node = cur_node_parent
#     end
# end
# required_iris = ["http://purl.obolibrary.org/obo/CL_0000084",
#                  "http://purl.obolibrary.org/obo/CL_0000236",
#                  "http://purl.obolibrary.org/obo/CL_0000235"]

# required_iris = ["http://purl.obolibrary.org/obo/CL_0000787"
#                  "http://purl.obolibrary.org/obo/CL_0000625"
#                  "http://purl.obolibrary.org/obo/CL_0000788"
#                  "http://purl.obolibrary.org/obo/CL_0000897"
#                  "http://purl.obolibrary.org/obo/CL_0000898"
#                  "http://purl.obolibrary.org/obo/CL_0000623"
#                  "http://purl.obolibrary.org/obo/CL_0000798"
#                  "http://purl.obolibrary.org/obo/CL_0000897"
#                  # "http://purl.obolibrary.org/obo/CL_0000576"
#                  ]

# root_iri = "http://purl.obolibrary.org/obo/CL_0000988"  # Hematopoietic cell
