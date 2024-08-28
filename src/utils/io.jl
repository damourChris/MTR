using JLD2
using RCall
using LightXML

function save_eset(eset::ExpressionSet, eset_id::String, file::String)
    # Check wether to save to JLD2 or to R
    if endswith(file, ".jld2")
        save_to_jld2(eset::ExpressionSet, eset_id::String, file::String)
    elseif endswith(file, ".rds")
        save_to_r_eset(eset::ExpressionSet, eset_id::String, file::String)
    else
        @error "The file extension is not supported. Please use either .jld2 or .rds"
    end
end

function save_to_jld2(eset::ExpressionSet, eset_id::String, file::String)
    return save(file, eset_id, eset)
end

function save_to_r_eset(eset::ExpressionSet, eset_id::String, file::String)
    exprsData = exprs(Matrix, eset)
    phenoData = pData(eset)
    featureData = fData(eset)
    R"""

    library(Biobase)

    phenoData <- new('AnnotatedDataFrame', data = $phenoData)
    featureData <- new('AnnotatedDataFrame', data = $featureData)

    eset <- new(
        'ExpressionSet', 
        exprs = $exprsData, 
        phenoData = phenoData,
        featureData = featureData
    )

    saveRDS(eset, $file)
    """
end

function export_to_graphxml(graph::MetaDiGraph, filename::String)
    xdoc = XMLDocument()

    # Create the root element
    xroot = create_root(xdoc, "graphml")
    set_attribute(xroot, "xmlns", "http://graphml.graphdrawing.org/xmlns")

    # For each fieldnames in the Term struct, create a key element
    for field in fieldnames(Term)
        xkey = new_child(xroot, "key")
        set_attribute(xkey, "id", field)
        set_attribute(xkey, "for", "node")
        set_attribute(xkey, "attr.name", field)
        set_attribute(xkey, "attr.type", "string")
    end

    for field in [:gene_id, :type, :label]
        xkey = new_child(xroot, "key")
        set_attribute(xkey, "id", field)
        set_attribute(xkey, "for", "node")
        set_attribute(xkey, "attr.name", field)
        set_attribute(xkey, "attr.type", "string")
    end

    for field in [:expression, :proportion]
        xkey = new_child(xroot, "key")
        set_attribute(xkey, "id", field)
        set_attribute(xkey, "for", "node")
        set_attribute(xkey, "attr.name", field)
        set_attribute(xkey, "attr.type", "float")
    end

    # Define graph attributes
    xgraph = new_child(xroot, "graph")
    set_attribute(xgraph, "id", "G")
    set_attribute(xgraph, "edgedefault", "directed") # Assuming directed graph

    vertice_with_term_prop = [v_index
                              for (v_index, v_props) in graph.vprops
                              if haskey(v_props, :term)]

    # Add term node metadata
    for v in vertice_with_term_prop
        xnode = new_child(xgraph, "node")
        set_attribute(xnode, "id", string(v))

        term = get_prop(graph, v, :term)

        xdata = new_child(xnode, "data")
        set_attribute(xdata, "key", :type)
        add_text(xdata, "cell")

        for field in fieldnames(Term)
            xdata = new_child(xnode, "data")
            set_attribute(xdata, "key", field)
            add_text(xdata, string(getfield(term, field)))
        end

        try
            proportion = get_prop(graph, v, :proportion)
            if ismissing(proportion)
                continue
            end
            xdata = new_child(xnode, "data")
            set_attribute(xdata, "key", :proportion)
            add_text(xdata, string(proportion))
        catch
            continue
        end
    end

    vertice_with_gene_prop = [v_index
                              for (v_index, v_props) in graph.vprops
                              if haskey(v_props, :gene_id)]

    # Add term node metadata
    for v in vertice_with_gene_prop
        xnode = new_child(xgraph, "node")
        set_attribute(xnode, "id", string(v))

        gene_id = get_prop(graph, v, :gene_id)
        xdata = new_child(xnode, "data")
        set_attribute(xdata, "key", :gene_id)
        add_text(xdata, string(gene_id))

        gene_expression = get_prop(graph, v, :expression)
        if (!ismissing(gene_expression))
            xdata = new_child(xnode, "data")
            set_attribute(xdata, "key", :expression)
            add_text(xdata, string(gene_expression))
        end

        xdata = new_child(xnode, "data")
        set_attribute(xdata, "key", :label)
        add_text(xdata, string(gene_id))

        xdata = new_child(xnode, "data")
        set_attribute(xdata, "key", :type)
        add_text(xdata, "gene")
    end

    # Add edges
    for e in edges(graph)
        xedge = new_child(xgraph, "edge")
        set_attribute(xedge, "source", string(src(e)))
        set_attribute(xedge, "target", string(dst(e)))
    end

    # Save XML document to file
    return save_file(xdoc, filename)
end

function get_element_type(node::XMLElement)
    child_elmts = collect(child_elements(node))
    if length(child_elmts) == 0
        return missing
    end
    xdata = [x for x in child_elmts if attribute(x, "key") == "type"][1]
    return content(xdata)
end