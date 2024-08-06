using Graphs
using GraphRecipes
using MetaGraphs
using OntologyLookup
using Plots

struct OntologyTree
    graph::MetaGraphs.MetaDiGraph
    root::Term
    required_terms::Vector{Term}
    max_parent_limit::Int
end

function OntologyTree(root::Term,
                      required_terms::Vector{Term}=[];
                      max_parent_limit::Int=5)
    graph = MetaDiGraph()
    return OntologyTree(graph, root, required_terms, max_parent_limit)
end

function populate!(onto_tree::OntologyTree)::Nothing
    required_terms = get_required_terms(onto_tree)
    base_term = get_base_term(onto_tree)
    graph = get_graph(onto_tree)

    for (index, term) in enumerate(required_terms)
        add_vertex!(graph)
        set_term_props!(graph, term, index)
    end

    for (index, node) in enumerate(required_terms)
        check_parent_limit = get_parent_limit(onto_tree)

        # While the parents list doesnt contain the base node, keep getting the hiercahical parents
        cur_node = node # Start with the current node
        @info "Currently on node: $(cur_node.label)"
        while check_parent_limit > 0
            @info "Current node is: $(cur_node.label)"
            @info "Current parent limit is: $check_parent_limit"
            if cur_node == base_term
                @info "Reached base node: $(base_term.label). Stopping."
                break
            end

            cur_node_parent = get_hierarchical_parent(cur_node; preferred_parent=base_term)
            cur_node_index = get_vertex_number_by_term_id(graph, cur_node.obo_id)

            if ismissing(cur_node)
                @warn "Error fetching parents for node: $cur_node. Skipping."
                break
            end

            # Check if the parent is already in the graph 
            if is_term_in_graph(graph, cur_node_parent)
                @info "Parent: $(cur_node_parent.label) already in graph. Stopping."
                existing_parent_index = get_vertex_number_by_term_id(graph,
                                                                     cur_node_parent.obo_id)
                add_edge!(graph, cur_node_index, existing_parent_index)
                break
            end

            @info "Adding parent: $(cur_node_parent.label)"
            add_vertex!(graph)

            # Connect the parent to the current node
            cur_parent_index = nv(graph)
            add_edge!(graph, cur_node_index, cur_parent_index)
            set_term_props!(graph, cur_node_parent, cur_parent_index)

            check_parent_limit -= 1
            cur_node = cur_node_parent
        end
    end

    return nothing
end

function add_genes!(onto_tree::OntologyTree, genes::Vector{String})::Nothing
    graph = get_graph(onto_tree)
    cur_v_num = nv(graph)
    for (index, gene) in enumerate(genes)
        add_vertex!(graph)
        set_gene_props!(onto_tree.graph, gene, cur_v_num + index)
    end

    return nothing
end

function add_genes!(onto_tree::OntologyTree, genes::Vector{Tuple{String,Float64}})::Nothing
    graph = get_graph(onto_tree)
    cur_v_num = nv(graph)
    for (index, gene) in enumerate(genes)
        add_vertex!(graph)
        set_gene_props!(onto_tree.graph, gene, cur_v_num + index)
    end

    return nothing
end

function connect_term_genes!(onto_tree::OntologyTree,
                             pairings::Dict{Term,Vector{String}})::Nothing
    for (term, genes) in pairings
        @info "Connecting genes to term: $(term.label)"

        for gene in genes
            term_gene_edge_added = connect_term_gene!(onto_tree.graph, term, gene)
            if !term_gene_edge_added
                @warn "Error connecting gene: $gene to term: $(term.label). Skipping."
            end
        end
    end
end

function connect_term_gene!(graph::MetaGraphs.MetaDiGraph, term::Term, gene::String)::Bool
    term_index = get_vertex_number_by_term_id(graph, term.obo_id)
    if ismissing(term_index)
        @warn "Term: $(term.label) not found in graph. Skipping."
        return false
    end

    gene_index = get_vertex_number_by_gene(graph, gene)
    if ismissing(gene_index)
        @warn "Gene: $gene not found in graph. Skipping."
        return false
    end

    return add_edge!(graph, gene_index, term_index)
end

function get_parent_limit(onto_tree::OntologyTree)::Int
    return onto_tree.max_parent_limit
end

function get_required_terms(onto_tree::OntologyTree)::Vector{Term}
    return onto_tree.required_terms
end

function get_base_term(onto_tree::OntologyTree)::Term
    return onto_tree.root
end

function get_graph(onto_tree::OntologyTree)::MetaGraphs.MetaDiGraph
    return onto_tree.graph
end
