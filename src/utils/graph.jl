
using Graphs
using MetaGraphs
using Plots

using OntologyLookup: Term

function is_term_in_graph(graph::MetaGraphs.MetaDiGraph, term::Term)
    for vertex in vertices(graph)
        if get_prop(graph, vertex, :id) == term.obo_id
            return true
        end
    end
    return false
end

function inspect_term_nodes(graph::MetaGraphs.MetaDiGraph)
    for vertex in vertices(graph)
        term = get_prop(graph, vertex, :term)
        println("Found term: $(term.short_form) at vertex: $vertex")
        display(term)
    end
end

function inspect_graph_edges(graph::MetaGraphs.MetaDiGraph)
    for edge in edges(graph)
        println(edge)
        src_e = src(edge)
        dst_e = dst(edge)
        src_term = get_prop(graph, src_e, :term)
        dst_term = get_prop(graph, dst_e, :term)
        println("Edge from $(src_term.label) to $(dst_term.label)")
    end
end

function plot_graph_with_labels(graph::MetaGraphs.MetaDiGraph)
    labels = Dict()
    for vertex in vertices(graph)
        try # Skip if the vertex does not have a term
            term = get_prop(graph, vertex, :term)
            labels[vertex] = term.label
        catch
            continue
        end
    end
    @show labels
    return plot(SimpleDiGraph(graph); names=labels, fontsize=5, nodesize=0.1,
                nodeshape=:rect, method=:spring)
end

function get_vertex_number_by_term_id(graph::MetaGraphs.MetaDiGraph, term_id::String)
    return get_vertex_number_by_prop(graph, :id, term_id)::Union{Int,Missing}
end

function get_vertex_number_by_gene(graph::MetaGraphs.MetaDiGraph, gene::String)
    return get_vertex_number_by_prop(graph, :gene, gene)::Union{Int,Missing}
end

function get_vertex_number_by_prop(graph::MetaGraphs.MetaDiGraph, prop::Symbol,
                                   value)::Union{Int,Missing}
    for vertex in vertices(graph)
        if get_prop(graph, vertex, prop) == value
            return vertex
        end
    end
    return missing
end

function set_term_props!(graph::MetaGraphs.MetaDiGraph, term::Term, vertex_id::Int)::Bool
    return set_prop!(graph, vertex_id, :term, term) &
           set_prop!(graph, vertex_id, :id, term.obo_id)
end

function set_gene_props!(graph::MetaGraphs.MetaDiGraph, gene::String,
                         vertex_id::Int)::Bool
    return set_prop!(graph, vertex_id, :gene_id, gene) &
           set_prop!(graph, vertex_id, :expression, missing)
end

function set_gene_props!(graph::MetaGraphs.MetaDiGraph, gene::Tuple{String,Float64},
                         vertex_id::Int)::Bool
    return set_prop!(graph, vertex_id, :gene_id, gene[1]) &
           set_prop!(graph, vertex_id, :expression, gene[2])
end
