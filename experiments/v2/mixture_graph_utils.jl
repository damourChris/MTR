
function create_mixture_graph_for_sample(ref_graph::OntologyTree,
                                         sample_cell_proportion::Vector{Tuple{String,
                                                                              Float64}},
                                         gx_sample_with_id::Vector{Tuple{String,Float64}})

    # @info "Processing sample: $sample_id"
    mix_tree = deepcopy(ref_graph)

    # @info "Adding gene expression"
    add_gene_expression!(mix_tree, gx_sample_with_id)

    # @info "Adding cell proportions"
    add_cell_proportions!(mix_tree, sample_cell_proportion)

    # @info "Propagating cell proportions"
    propagate_cell_proportions!(mix_tree)

    return mix_tree
end

# function get_cell_types(eset::ExpressionSet, pheno_col::String;
#                         cell_seperator=";", value_seperator="=")
#     proportions = eset.phenoData[!, pheno_col]
#     splits = split.(proportions, cell_seperator)
#     cell_types_raw = [split.(x, value_seperator) for x in splits]
#     cell_types = unique([strip.(getindex.(x, 1)) for x in cell_types_raw])
#     return [String.(cell) for cell in cell_types if cell != ["NA"]][1]
# end

function get_cell_type_proportions(eset::ExpressionSet, pheno_col::String;
                                   cell_seperator=";", value_seperator="=")
    proportions = eset.phenoData[!, pheno_col]
    splits = split.(proportions, cell_seperator)
    cell_types_raw = [split.(x, value_seperator) for x in splits]

    cell_types = get_cell_types(eset, pheno_col)

    na_indices = findall(x -> x == [["NA"]], cell_types_raw)

    cell_types_raw = [cell_types_raw[i]
                      for i in eachindex(cell_types_raw) if i ∉ na_indices]

    cell_values = [getindex.(split, 2) for split in cell_types_raw]
    cell_values = [strip.(vals) for vals in cell_values]
    cell_values = [replace.(vals, "%" => "") for vals in cell_values]
    cell_values = [parse.(Float64, value) for value in cell_values]

    # Make a matrix
    cell_values = transpose(hcat(cell_values...))

    df = DataFrame(cell_values, cell_types)

    # Add sample ids  
    sample_names = sampleNames(eset)
    sample_names = [sample_names[i]
                    for i in eachindex(sample_names) if i ∉ na_indices]

    df[!, :sample_id] = sample_names
    return df
end

function get_parent(graph::MetaGraphs.MetaDiGraph, vertex::Int)
    for edge in edges(graph)
        if src(edge) == vertex
            return dst(edge)
        end
    end

    return nothing
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

    # @info "Propagating proportions for terms: $(terms_to_propagate)"

    for vertex in proportions_to_propagate
        # @info "Propagating proportion for term: $(get_prop(graph, vertex, :term).label)"
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

        # @info "Propagating proportion: $proportion to parent: $(get_prop(graph, parent_index, :term).label)"
        propagate_proportion_to_parent!(onto_tree, parent_index, proportion)
    end

    # @info "Proportion propagation done."
    # @info "Setting the proportion of all the remaining cell_type cells to 0"

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