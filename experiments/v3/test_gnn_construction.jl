"""
Test script for GNNGraph construction from OntologyTrees
"""

using OntologyTrees
using OntologyLookup

# Include our new modules
include("graphs/gnn_graph_construction.jl")
include("models/ontology_enhanced_gnn_clean.jl")

function test_gnn_graph_construction()
    @info "Testing GNNGraph construction from OntologyTrees"
    
    try
        # Create a simple test ontology tree (similar to v2/main.jl)
        onto = "cl"
        base_term_iri = "http://purl.obolibrary.org/obo/CL_0000988"  # Hematopoietic cell
        base_term = onto_term(onto, base_term_iri)
        
        # Define some test cell types
        test_cell_types = ["CD4+ T cell", "CD8+ T cell", "B cell", "NK cell", "Monocyte"]
        test_gene_symbols = ["CD3D", "CD4", "CD8A", "CD19", "FCGR3A", "CD14", "GZMB"]
        
        # Create test data
        n_genes = length(test_gene_symbols)
        n_cells = length(test_cell_types)
        n_samples = 5
        
        X_reference = rand(Float64, n_genes, n_samples * 10)  # Reference expression
        cell_proportions = rand(Float64, n_cells, n_samples)  # Random proportions
        
        # Normalize proportions to sum to 1
        for i in 1:n_samples
            cell_proportions[:, i] = cell_proportions[:, i] / sum(cell_proportions[:, i])
        end
        
        # Create a simple ontology tree
        # For testing, we'll create required terms for common immune cells
        required_terms = []
        
        # Try to get ontology terms for common immune cell types
        try
            cd4_terms = onto_terms(onto; id="CL:0000624")  # CD4+ T cell
            if !isempty(cd4_terms)
                push!(required_terms, cd4_terms[1][2])
            end
        catch e
            @warn "Could not find CD4+ T cell term: $e"
        end
        
        try
            cd8_terms = onto_terms(onto; id="CL:0000625")  # CD8+ T cell  
            if !isempty(cd8_terms)
                push!(required_terms, cd8_terms[1][2])
            end
        catch e
            @warn "Could not find CD8+ T cell term: $e"
        end
        
        # Create ontology tree
        if !isempty(required_terms)
            onto_tree = OntologyTree(base_term, required_terms; max_parent_limit=20)
            populate!(onto_tree)
            
            @info "Created ontology tree with $(length(required_terms)) terms"
            
            # Test GNN graph construction
            @info "Testing GNNGraph construction..."
            gnn_graph, gene_term_connections = ontology_tree_to_gnn_graph(
                onto_tree, X_reference, test_gene_symbols, cell_proportions, test_cell_types;
                include_string_edges=false,  # Disable STRING for testing
                include_hierarchy_edges=true
            )
            
            @info "✓ GNNGraph construction successful!"
            @info "Node types: $(keys(gnn_graph.ndata))"
            @info "Edge types: $(keys(gnn_graph.edge_indices))"
            
            # Test model creation (without training)
            @info "Testing model creation..."
            
            # Create dummy reference data for model
            y_reference = repeat(test_cell_types, 10)  # Reference labels
            X_mixture = rand(Float64, n_genes, n_samples)  # Mixture data
            y_mixture = cell_proportions  # Target proportions
            
            model = OntologyEnhancedGNN(onto_tree, X_reference, test_gene_symbols, 
                                       cell_proportions, test_cell_types; use_ontology=true)
            
            @info "✓ Model creation successful!"
            
            # Test forward pass
            @info "Testing forward pass..."
            prediction = model(gnn_graph)
            @info "✓ Forward pass successful! Prediction shape: $(size(prediction))"
            
            return true
            
        else
            @warn "No valid ontology terms found for testing"
            return false
        end
        
    catch e
        @error "Test failed: $e"
        return false
    end
end

# Run the test
if abspath(PROGRAM_FILE) == @__FILE__
    success = test_gnn_graph_construction()
    if success
        @info "🎉 All tests passed!"
    else
        @error "❌ Tests failed!"
    end
end
