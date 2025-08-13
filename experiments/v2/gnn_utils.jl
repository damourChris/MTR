function visualize_tsne(out, targets)
    z = tsne(out, 2)
    return scatter(z[:, 1], z[:, 2]; color=Int.(targets[1:size(z, 1)]), leg=false)
end

# Count the number of nodes in the graph that are cell types
function count_cell_types(graph::MetaGraphs.MetaDiGraph)
    return length([v_index
                   for (v_index, v_props) in graph.vprops
                   if haskey(v_props, :term)])
end

function count_genes(graph::MetaGraphs.MetaDiGraph)
    return length([v_index
                   for (v_index, v_props) in graph.vprops
                   if haskey(v_props, :gene_id)])
end

function export_to_graphxml(graph::GNNHeteroGraph, filename::String)
    xdoc = XMLDocument()

    xroot = create_root(xdoc, "graphml")
    set_attribute(xroot, "xmlns", "http://graphml.graphdrawing.org/xmlns")

    xgraph = new_child(xroot, "graph")
    set_attribute(xgraph, "id", "G")
    set_attribute(xgraph, "edgedefault", "directed")

    # Add the nodes
    for (node_type, node_number) in graph.num_nodes
        for node_index in 1:node_number
            xnode = new_child(xgraph, "node")
            set_attribute(xnode, "id", string(node_index))
            set_attribute(xnode, "type", node_type)
        end
    end

    # Add the edges
    src_indices, dst_indices, _ = collect(values(graph.graph))[1]

    for (src, dst) in zip(src_indices, dst_indices)
        xedge = new_child(xgraph, "edge")
        set_attribute(xedge, "source", string(src))
        set_attribute(xedge, "target", string(dst))
    end

    return save_file(xdoc, filename)
end
