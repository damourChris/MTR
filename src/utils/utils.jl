module Utils

include(joinpath(@__DIR__, "preprocessing.jl"))
export preprocess_data

include(joinpath(@__DIR__, "custom_conversion.jl"))
export
       ExpressionSet,
       fData,
       fData!,
       pData,
       pData!,
       add_pheno_column!,
       exprs,
       featureNames,
       sampleNames,
       save_to_r_eset,
       load_eset

include(joinpath(@__DIR__, "strings.jl"))
export is_loosely_the_same

include(joinpath(@__DIR__, "graph.jl"))
export is_term_in_graph,
       inspect_term_nodes,
       plot_graph_with_labels,
       get_vertex_number_by_term_id,
       get_vertex_number_by_gene,
       get_vertex_number_by_prop,
       set_term_props!,
       set_gene_props!

include(joinpath(@__DIR__, "io.jl"))
export save_eset, export_to_graphxml, save_to_r_eset

end