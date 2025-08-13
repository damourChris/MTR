#!/usr/bin/env julia

"""
Simple test for GNNGraph construction from OntologyTrees
Fixed to work with actual OntologyLookup API
"""

using Pkg
Pkg.activate(".")

using OntologyTrees
using OntologyLookup
using GraphNeuralNetworks
using Random

include("graphs/gnn_graph_construction.jl")

function test_simple_gnn_construction()
    @info "Testing simplified GNNGraph construction"
    
    # Create simple test data
    Random.seed!(42)
    
    n_genes = 50
    n_samples = 10
    n_cell_types = 3
    
    test_gene_symbols = ["GENE_$i" for i in 1:n_genes]
    test_cell_types = ["CD4_T", "CD8_T", "B_cell"]
    
    # Create test expression data
    X_reference = rand(Float64, n_genes, n_samples)
    
    # Create test cell proportions  
    cell_proportions = rand(Float64, n_cell_types, n_samples)
    # Normalize to sum to 1
    for j in 1:n_samples
        cell_proportions[:, j] = cell_proportions[:, j] / sum(cell_proportions[:, j])
    end
    
    try
        @info "Creating ontology terms..."
        
        # Create base term
        base_term = onto_term("cl", "http://purl.obolibrary.org/obo/CL_0000988")  # Hematopoietic cell
        
        # Create required terms for our cell types
        required_terms = [
            onto_term("cl", "http://purl.obolibrary.org/obo/CL_0000624"),  # CD4+ T cell
            onto_term("cl", "http://purl.obolibrary.org/obo/CL_0000625"),  # CD8+ T cell  
            onto_term("cl", "http://purl.obolibrary.org/obo/CL_0000236"),  # B cell
        ]
        
        @info "Creating OntologyTree..."
        onto_tree = OntologyTree(base_term, required_terms; max_parent_limit=20)
        populate!(onto_tree)
        
        @info "Adding genes to ontology tree..."
        # Add some genes to the tree (simplified)
        genes_to_add = test_gene_symbols[1:10]  # Add first 10 genes
        add_genes!(onto_tree, genes_to_add)
        
        # Connect genes to terms (simplified mapping)
        gene_term_mapping = Dict{Any, Vector{String}}(
            required_terms[1] => test_gene_symbols[1:5],   # CD4 genes
            required_terms[2] => test_gene_symbols[6:10],  # CD8 genes  
            required_terms[3] => test_gene_symbols[11:15]  # B cell genes
        )
        
        connect_term_genes!(onto_tree, gene_term_mapping)
        
        @info "Testing GNNGraph construction..."
        gnn_graph, gene_term_connections = ontology_tree_to_gnn_graph(
            onto_tree, X_reference, test_gene_symbols, cell_proportions, test_cell_types;
            include_string_edges=false,  # Disable STRING for testing
            include_hierarchy_edges=true
        )
        
        @info "✓ GNNGraph construction successful!"
        @info "Node types: $(keys(gnn_graph.ndata))"
        @info "Edge types: $(keys(gnn_graph.edge_indices))"
        
        # Print some statistics
        for (node_type, features) in gnn_graph.ndata
            @info "Node type '$node_type': $(size(features)) features"
        end
        
        for (edge_type, indices) in gnn_graph.edge_indices
            @info "Edge type '$edge_type': $(size(indices, 2)) edges"
        end
        
        @info "✓ All tests passed!"
        return true
        
    catch e
        @error "❌ Test failed: $e"
        @error "Stack trace:" exception=(e, catch_backtrace())
        return false
    end
end

# Run the test
if abspath(PROGRAM_FILE) == @__FILE__
    success = test_simple_gnn_construction()
    if success
        @info "🎉 All tests completed successfully!"
    else
        @error "❌ Tests failed!"
    end
end
