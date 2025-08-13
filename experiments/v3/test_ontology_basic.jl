#!/usr/bin/env julia

"""
Simple test that mimics the exact pattern from v2/main.jl
"""

using Pkg
Pkg.activate(".")

using OntologyLookup
using OntologyTrees

function test_ontology_creation()
    @info "Testing ontology creation with exact v2 pattern"
    
    try
        # Exactly like v2
        onto = "cl"
        base_term_iri = "http://purl.obolibrary.org/obo/CL_0000988"  # Hematopoietic cell
        base_term = onto_term(onto, base_term_iri)
        
        @info "Base term created: $(base_term.label)"
        
        # Create required terms list
        required_terms = Term[]
        
        # Add a few terms
        term1 = onto_term(onto, "http://purl.obolibrary.org/obo/CL_0000624")  # CD4+ T cell
        term2 = onto_term(onto, "http://purl.obolibrary.org/obo/CL_0000625")  # CD8+ T cell
        
        push!(required_terms, term1)
        push!(required_terms, term2)
        
        @info "Required terms: $(length(required_terms))"
        
        # Create ontology tree exactly like v2
        onto_tree = OntologyTree(base_term, required_terms; max_parent_limit=20)
        
        @info "✓ OntologyTree created successfully!"
        
        # Populate it
        populate!(onto_tree)
        
        @info "✓ OntologyTree populated successfully!"
        
        return true
        
    catch e
        @error "❌ Failed: $e"
        @error "Stack trace:" exception=(e, catch_backtrace())
        return false
    end
end

# Run the test
if abspath(PROGRAM_FILE) == @__FILE__
    success = test_ontology_creation()
    if success
        @info "🎉 Test passed!"
    else
        @error "❌ Test failed!"
    end
end
