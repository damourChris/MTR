
function to_hetero_gnn(onto_tree::OntologyTree)
    graph = onto_tree.graph

    # To construct, the GNNHeteroGraph we need 2 vectors that describes the edges:
    # - one for the genes
    # - one for the cell types
    # These vectors needs to be in the same order
    # That, is (vector1[index1], vector2[index1]) 
    # represents the edge between the gene at index1 and the cell type at index1
    gene_index_vector = [v_index
                         for (v_index, v_props) in graph.vprops
                         if haskey(v_props, :gene_id)]
    cell_index_ref_vector = [v_index
                             for (v_index, v_props) in graph.vprops
                             if haskey(v_props, :term)]

    # In the hetero gnn, each node type is indexed separetely 
    # So we create 2 new vectors for each node type
    # We make a dict for each that represents the mapping
    # Then we an create the edge vector with the new indices 

    gene_indices_mapping = Dict([gene_index_vector[index] => index
                                 for index in
                                     eachindex(gene_index_vector)])
    cell_indices_mapping = Dict([cell_index_ref_vector[index] => index
                                 for index in eachindex(cell_index_ref_vector)])

    # Now we can create the edge vectors
    # We are gonna have a single dict where each entries is an edge type
    # The value of each entry is a tuple with the source and destination indices
    # of the edges
    edge_dict = Dict{NTuple{3,Symbol},Tuple{Vector{Int},Vector{Int}}}()

    # To find out the edges we need to iterate over the edges
    # and find the new indices of the nodes
    for edge in edges(graph)
        src_e = src(edge)
        dst_e = dst(edge)

        src_type = haskey(graph.vprops[src_e], :gene_id) ? :gene : :cell
        dst_type = haskey(graph.vprops[dst_e], :gene_id) ? :gene : :cell

        src_index = haskey(graph.vprops[src_e], :gene_id) ?
                    gene_indices_mapping[src_e] :
                    cell_indices_mapping[src_e]

        dst_index = haskey(graph.vprops[dst_e], :gene_id) ?
                    gene_indices_mapping[dst_e] :
                    cell_indices_mapping[dst_e]

        edge_type = (src_type, :to, dst_type)
        if haskey(edge_dict, edge_type)
            push!(edge_dict[edge_type][1], src_index)
            push!(edge_dict[edge_type][2], dst_index)
        else
            edge_dict[edge_type] = ([src_index], [dst_index])
        end
    end

    # Now we have to deal with the node features
    # We are gonna have a single dict where each entries is an node type
    # The value of each entry is a matrix with the features of the nodes
    ndata = Dict{Symbol,DataStore}()

    # Fill the datastore with the gene expression
    gene_expressions = [graph.vprops[gene_index][:expression]
                        for gene_index in gene_index_vector]
    ndata[:gene] = DataStore(; exprs=gene_expressions)

    # Fill the datastore with the cell type proportion
    cell_proportions = [haskey(graph.vprops[index], :proportion) ?
                        graph.vprops[index][:proportion] : missing
                        for index in cell_index_ref_vector]
    ndata[:cell] = DataStore(; proportion=cell_proportions)

    # Now we can create the GNNHeteroGraph
    g = GNNHeteroGraph(edge_dict; ndata)

    return g
end