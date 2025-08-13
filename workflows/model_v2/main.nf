reference_esets = Channel.fromPath("input/reference_esets")
graphs = Channel.fromPath("output/graphs")

process create_reference_graph {
    input:
        file eset from reference_esets
    output:
        file("${eset.baseName}.graph.jld2") into graphs
    
    script:
    """
    ontolinker ${eset} -o ${eset.baseName}.graph.jld2
    """
}