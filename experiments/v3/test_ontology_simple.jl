#!/usr/bin/env julia

"""
Test using OntologyTrees package without keyword arguments
"""

using Pkg
Pkg.activate(".")

using OntologyLookup
using OntologyTrees

function test_ontology_no_kwargs()
    @info "Testing ontology creation without keyword arguments"
    
    try
        # Create terms
        onto = "cl"
        base_term = onto_term(onto, "http://purl.obolibrary.org/obo/CL_0000988")
        
        required_terms = [
            onto_term(onto, "http://purl.obolibrary.org/obo/CL_0000624"),  # CD4+ T cell
            onto_term(onto, "http://purl.obolibrary.org/obo/CL_0000625"),  # CD8+ T cell
        ]
        
        @info "Terms created successfully"
        
        # Try different constructor patterns
        @info "Trying constructor with just base_term and required_terms..."
        
        # Use the 2-argument constructor
        onto_tree = OntologyTree(base_term, required_terms)
        
        @info "✓ OntologyTree created successfully!"
        
        # Try to populate
        populate!(onto_tree)
        
        @info "✓ OntologyTree populated successfully!"
        
        return onto_tree
        
    catch e
        @error "❌ Failed: $e"
        @error "Stack trace:" exception=(e, catch_backtrace())
        return nothing
    end
end

# Run the test
if abspath(PROGRAM_FILE) == @__FILE__
    result = test_ontology_no_kwargs()
    if result !== nothing
        @info "🎉 Test passed!"
        @info "Tree has $(length(result.required_terms)) required terms"
    else
        @error "❌ Test failed!"
    end
end
