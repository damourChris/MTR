"""
Ontology-Enhanced GNN Model for V3  
Integrates GNNHeteroGraph from OntologyTrees and STRINGdb
Uses real biological graphs with multi-dimensional features
"""

using Flux
using GraphNeuralNetworks
using Graphs
using MetaGraphs
using JLD2
using Statistics
using STRINGdb
using OntologyTrees

# Include the new biological graph integration
include("../graphs/string_integration.jl")
include("../graphs/ontology_integration.jl")
include("../graphs/gnn_conversion.jl")

"""
Enhanced GNN that processes GNNHeteroGraph with biological constraints
"""
struct OntologyEnhancedGNN
    # Gene processing layers
    gene_encoder::Dense
    gene_conv_layers::Chain
    
    # Cell processing layers  
    cell_encoder::Dense
    cell_conv_layers::Chain
    
    # Cross-modal attention
    gene_attention::Dense
    cell_attention::Dense
    cross_attention::Dense
    
    # Final prediction layers
    fusion_layer::Dense
    proportion_decoder::Chain
    
    # Metadata
    cell_types::Vector{String}
    gene_symbols::Vector{String}
    use_ontology::Bool
    hetero_graph::Union{GNNHeteroGraph, Nothing}
end

function OntologyEnhancedGNN(onto_trees::Vector{OntologyTree}, 
                            gene_expressions_batch::Vector{Matrix{Float64}},
                            gene_symbols::Vector{String},
                            cell_types::Vector{String}; 
                            use_ontology::Bool=true,
                            hidden_dim::Int=64)
    
    @info "Building OntologyEnhancedGNN with GNNHeteroGraph integration"
    
    # Convert ontology trees to GNNHeteroGraphs
    hetero_graphs = batch_ontology_trees_to_gnn(
        onto_trees, gene_expressions_batch, gene_symbols; 
        include_string_edges=use_ontology
    )
    
    # Use first graph as template for architecture design
    template_graph = hetero_graphs[1]
    
    # Get feature dimensions from the hetero graph
    gene_feature_dim = size(template_graph.ndata[:gene].features, 1)
    cell_feature_dim = size(template_graph.ndata[:cell].features, 1)
    n_cell_types = length(cell_types)
    
    @info "Gene feature dim: $gene_feature_dim, Cell feature dim: $cell_feature_dim"
    
    # Gene processing pipeline
    gene_encoder = Dense(gene_feature_dim, hidden_dim, relu)
    gene_conv_layers = Chain(
        HeteroGraphConv(Dict(
            (:gene, :string, :gene) => GCNConv(hidden_dim => hidden_dim, relu),
            (:gene, :ontology, :cell) => GCNConv(hidden_dim => hidden_dim, relu)
        )),
        Dropout(0.3),
        HeteroGraphConv(Dict(
            (:gene, :string, :gene) => GCNConv(hidden_dim => hidden_dim, relu),
            (:gene, :ontology, :cell) => GCNConv(hidden_dim => hidden_dim, relu)
        )),
        Dropout(0.3)
    )
    
    # Cell processing pipeline
    cell_encoder = Dense(cell_feature_dim, hidden_dim, relu)
    cell_conv_layers = Chain(
        HeteroGraphConv(Dict(
            (:cell, :hierarchy, :cell) => GCNConv(hidden_dim => hidden_dim, relu),
            (:cell, :ontology, :gene) => GCNConv(hidden_dim => hidden_dim, relu)
        )),
        Dropout(0.3),
        HeteroGraphConv(Dict(
            (:cell, :hierarchy, :cell) => GCNConv(hidden_dim => hidden_dim, relu),
            (:cell, :ontology, :gene) => GCNConv(hidden_dim => hidden_dim, relu)
        )),
        Dropout(0.3)
    )
    
    # Attention mechanisms for cross-modal interaction
    gene_attention = Dense(hidden_dim, hidden_dim, tanh)
    cell_attention = Dense(hidden_dim, hidden_dim, tanh)
    cross_attention = Dense(hidden_dim * 2, hidden_dim, relu)
    
    # Final prediction layers with biological constraints
    fusion_layer = Dense(hidden_dim, hidden_dim÷2, relu)
    proportion_decoder = Chain(
        Dense(hidden_dim÷2, n_cell_types),
        softmax  # Ensures proportions sum to 1
    )
    
    return OntologyEnhancedGNN(
        gene_encoder, gene_conv_layers, cell_encoder, cell_conv_layers,
        gene_attention, cell_attention, cross_attention,
        fusion_layer, proportion_decoder,
        cell_types, gene_symbols, use_ontology, template_graph
    )
end

"""
Forward pass through the OntologyEnhancedGNN
"""
function (model::OntologyEnhancedGNN)(hetero_graph::GNNHeteroGraph)
    # Extract node features
    gene_features = hetero_graph.ndata[:gene].features
    cell_features = hetero_graph.ndata[:cell].features
    
    # Encode features
    encoded_genes = model.gene_encoder(gene_features)
    encoded_cells = model.cell_encoder(cell_features)
    
    # Apply heterogeneous graph convolutions
    conv_genes = model.gene_conv_layers[1](hetero_graph, Dict(:gene => encoded_genes, :cell => encoded_cells))[:gene]
    conv_cells = model.cell_conv_layers[1](hetero_graph, Dict(:gene => encoded_genes, :cell => encoded_cells))[:cell]
    
    # Apply dropout and second convolution
    conv_genes = model.gene_conv_layers[2](conv_genes)  # Dropout
    conv_cells = model.cell_conv_layers[2](conv_cells)  # Dropout
    
    # Second convolution layer
    conv_genes = model.gene_conv_layers[3](hetero_graph, Dict(:gene => conv_genes, :cell => conv_cells))[:gene]
    conv_cells = model.cell_conv_layers[3](hetero_graph, Dict(:gene => conv_genes, :cell => conv_cells))[:cell]
    
    # Apply attention mechanisms
    attended_genes = model.gene_attention(conv_genes)
    attended_cells = model.cell_attention(conv_cells)
    
    # Global pooling for genes and cells
    pooled_genes = mean(attended_genes, dims=2)  # Pool over gene nodes
    pooled_cells = mean(attended_cells, dims=2)  # Pool over cell nodes
    
    # Cross-modal fusion
    fused_features = model.cross_attention(vcat(pooled_genes, pooled_cells))
    
    # Final prediction
    final_features = model.fusion_layer(fused_features)
    proportions = model.proportion_decoder(final_features)
    
    return proportions
end

"""
Train Enhanced GNN using GNNHeteroGraphs with biological constraints
"""
function train_ontology_enhanced_gnn(onto_trees::Vector{OntologyTree},
                                    gene_expressions_batch::Vector{Matrix{Float64}}, 
                                    gene_symbols::Vector{String},
                                    y_mixture::Matrix, cell_types::Vector{String};
                                    use_ontology::Bool=true, config::NamedTuple)
    @info "Training OntologyEnhancedGNN with GNNHeteroGraph and biological constraints"
    
    Random.seed!(config.random_seed)
    
    # Build the enhanced GNN model
    model = OntologyEnhancedGNN(onto_trees, gene_expressions_batch, gene_symbols, 
                               cell_types; use_ontology=use_ontology, hidden_dim=64)
    
    # Convert ontology trees to GNNHeteroGraphs for training
    hetero_graphs = batch_ontology_trees_to_gnn(
        onto_trees, gene_expressions_batch, gene_symbols; 
        include_string_edges=use_ontology
    )
    
    # Training parameters
    optimizer = Adam(0.001)
    epochs = 50
    batch_size = min(length(hetero_graphs), 32)
    
    # Training history
    history = []
    
    @info "Starting training with $(length(hetero_graphs)) samples, batch_size=$batch_size"
    
    # Training loop
    for epoch in 1:epochs
        epoch_loss = 0.0
        n_batches = 0
        
        # Mini-batch training
        for batch_start in 1:batch_size:length(hetero_graphs)
            batch_end = min(batch_start + batch_size - 1, length(hetero_graphs))
            batch_graphs = hetero_graphs[batch_start:batch_end]
            batch_targets = y_mixture[:, batch_start:batch_end]
            
            # Forward pass with gradients
            loss_val, gradients = ontology_loss_and_gradients(model, batch_graphs, batch_targets)
            
            # Backward pass
            Flux.update!(optimizer, model, gradients)
            
            epoch_loss += loss_val
            n_batches += 1
        end
        
        avg_epoch_loss = epoch_loss / n_batches
        
        # Validation metrics
        if epoch % 10 == 0
            val_correlation = evaluate_ontology_model(model, hetero_graphs, y_mixture)
            val_rmse = calculate_ontology_rmse(model, hetero_graphs, y_mixture)
            
            push!(history, (epoch=epoch, train_loss=avg_epoch_loss, 
                          val_correlation=val_correlation, val_rmse=val_rmse))
            
            @info "Epoch $epoch: Loss = $(round(avg_epoch_loss, digits=4)), " *
                  "Correlation = $(round(val_correlation, digits=3)), " *
                  "RMSE = $(round(val_rmse, digits=3))"
        end
    end
    
    return model, history
end

"""
Compute loss with biological constraints for GNNHeteroGraph
"""
function ontology_loss_and_gradients(model::OntologyEnhancedGNN, hetero_graphs::Vector{GNNHeteroGraph}, 
                                    targets::Matrix)
    gradients = gradient(model) do m
        ontology_biological_loss(m, hetero_graphs, targets)
    end
    
    loss_val = ontology_biological_loss(model, hetero_graphs, targets)
    return loss_val, gradients[1]
end

function ontology_biological_loss(model::OntologyEnhancedGNN, hetero_graphs::Vector{GNNHeteroGraph}, 
                                 targets::Matrix)
    batch_size = length(hetero_graphs)
    predictions = zeros(Float32, length(model.cell_types), batch_size)
    
    # Forward pass for each graph in batch
    for (i, graph) in enumerate(hetero_graphs)
        pred = model(graph)
        predictions[:, i] = pred[:, 1]  # Extract single column
    end
    
    # Main MSE loss
    mse_loss = Flux.mse(predictions, targets)
    
    # Biological constraints
    sum_constraint = mean(abs.(sum(predictions, dims=1) .- 1.0))  # Proportions should sum to 1
    non_negative_constraint = mean(max.(-predictions, 0.0))       # Should be non-negative
    
    # Ontology consistency constraint
    hierarchy_constraint = model.use_ontology ? calculate_ontology_consistency(predictions, model.cell_types) : 0.0
    
    # Combined loss
    λ_sum = 0.1
    λ_nonneg = 0.1
    λ_hier = model.use_ontology ? 0.05 : 0.0
    
    total_loss = mse_loss + λ_sum * sum_constraint + λ_nonneg * non_negative_constraint + λ_hier * hierarchy_constraint
    
    return total_loss
end

"""
Predict using Enhanced GNN with GNNHeteroGraph
"""
function predict_ontology_enhanced_gnn(model::OntologyEnhancedGNN, hetero_graphs::Vector{GNNHeteroGraph})
    @info "Predicting with OntologyEnhancedGNN on $(length(hetero_graphs)) samples"
    
    batch_size = length(hetero_graphs)
    predictions = zeros(Float32, length(model.cell_types), batch_size)
    
    # Forward pass for each graph
    for (i, graph) in enumerate(hetero_graphs)
        pred = model(graph)
        predictions[:, i] = pred[:, 1]
    end
    
    return predictions
end

"""
Evaluation functions for the enhanced GNN
"""
function evaluate_ontology_model(model::OntologyEnhancedGNN, hetero_graphs::Vector{GNNHeteroGraph}, 
                                targets::Matrix)
    predictions = predict_ontology_enhanced_gnn(model, hetero_graphs)
    
    # Calculate correlation for each cell type
    correlations = []
    for i in 1:size(predictions, 1)
        if var(predictions[i, :]) > 1e-10 && var(targets[i, :]) > 1e-10
            push!(correlations, cor(predictions[i, :], targets[i, :]))
        else
            push!(correlations, 0.0)
        end
    end
    
    return mean(correlations)
end

function calculate_ontology_rmse(model::OntologyEnhancedGNN, hetero_graphs::Vector{GNNHeteroGraph}, 
                                targets::Matrix)
    predictions = predict_ontology_enhanced_gnn(model, hetero_graphs)
    return sqrt(Flux.mse(predictions, targets))
end

function calculate_ontology_consistency(predictions::Matrix, cell_types::Vector{String})
    # Simplified ontology consistency - penalize biologically implausible combinations
    # Real implementation would use actual ontology structure
    return 0.0  # Placeholder
end
    
    # Prepare training data
    X_train, y_train = prepare_training_data(X_reference, y_reference, X_mixture, y_mixture, cell_types)
    
    # Training parameters
    optimizer = Adam(0.001)
    epochs = 50
    
    # Training history
    history = []
    
    @info "Starting training for $epochs epochs..."
    
    # Training loop
    for epoch in 1:epochs
        # Forward pass with biological loss
        loss_val, gradients = biological_loss_and_gradients(model, X_train, y_train)
        
        # Backward pass
        Flux.update!(optimizer, model, gradients)
        
        # Validation metrics every 10 epochs
        if epoch % 10 == 0
            val_loss = evaluate_enhanced_model(model, X_train, y_train)
            val_correlation = calculate_enhanced_correlation(model, X_train, y_train)
            val_rmse = calculate_enhanced_rmse(model, X_train, y_train)
            
            push!(history, (epoch=epoch, train_loss=loss_val, val_loss=val_loss, 
                          val_correlation=val_correlation, val_rmse=val_rmse))
            
            @info "Epoch $epoch: Loss = $(round(loss_val, digits=4)), " *
                  "Correlation = $(round(val_correlation, digits=3)), " *
                  "RMSE = $(round(val_rmse, digits=3))"
        end
    end
    
    @info "Training completed!"
    return model, history
end

"""
Predict using enhanced GNN with biological graphs
"""
function predict_ontology_enhanced_gnn(model::OntologyEnhancedGNN, X::Matrix)
    @info "Predicting with OntologyEnhancedGNN using biological graph structure"
    
    n_samples = size(X, 2)
    
    # Create enhanced gene features
    enhanced_features = create_enhanced_gene_features(X, model.biological_graph, model.ontology_tree)
    
    # Gene encoding
    encoded_features = model.gene_encoder(enhanced_features)
    
    # Graph convolutions on biological structure
    if nv(model.biological_graph) > 0 && ne(model.biological_graph) > 0
        graph_features = encoded_features
        for layer in model.graph_conv_layers
            if layer isa Dropout
                graph_features = layer(graph_features)
            elseif layer isa GCNConv
                graph_features = layer(model.biological_graph, graph_features)
            end
        end
    else
        # Fallback if graph is empty
        graph_features = encoded_features
    end
    
    # Attention mechanism for biological relationships
    attended_features = model.attention_mechanism(graph_features)
    
    # Global pooling for each sample
    pooled_features = mean(attended_features, dims=1)  # Mean pooling across genes
    
    # Decode to proportions with biological constraints
    proportions = model.proportion_decoder(pooled_features)
    
    # Ensure biological constraints are satisfied
    proportions = enforce_biological_constraints(proportions, model.ontology_tree, model.use_ontology)
    
    return proportions
end

"""
Create enhanced gene features using biological graph and ontology
"""
function create_enhanced_gene_features(X::Matrix, biological_graph::SimpleGraph, ontology_tree)
    @info "Creating enhanced gene features using biological context"
    
    n_genes, n_samples = size(X)
    
    # Start with log-transformed expression
    log_expression = log2.(X .+ 1.0)
    
    # Add network-based features
    network_features = zeros(Float32, 3, n_genes)  # 3 additional features per gene
    
    if nv(biological_graph) > 0 && ne(biological_graph) > 0
        # Calculate centrality measures
        degrees = degree(biological_graph)
        
        # Degree centrality (normalized)
        network_features[1, :] = degrees ./ maximum(degrees .+ 1e-8)
        
        # Local clustering coefficient
        for i in 1:min(n_genes, nv(biological_graph))
            neighbors_i = neighbors(biological_graph, i)
            if length(neighbors_i) > 1
                # Count edges between neighbors
                edges_between_neighbors = 0
                for j in neighbors_i
                    for k in neighbors_i
                        if j < k && has_edge(biological_graph, j, k)
                            edges_between_neighbors += 1
                        end
                    end
                end
                max_possible_edges = length(neighbors_i) * (length(neighbors_i) - 1) / 2
                network_features[2, i] = edges_between_neighbors / max(max_possible_edges, 1)
            end
        end
        
        # Eigenvector centrality (simplified)
        try
            # Simple approximation: sum of neighbor degrees
            for i in 1:min(n_genes, nv(biological_graph))
                neighbor_degrees = sum(degrees[neighbors(biological_graph, i)])
                network_features[3, i] = neighbor_degrees / (maximum(degrees) * maximum(degrees) + 1e-8)
            end
        catch e
            @warn "Failed to compute eigenvector centrality: $e"
        end
    else
        # Fallback: use correlation-based features
        correlation_matrix = cor(X, dims=2)
        for i in 1:n_genes
            correlations = abs.(correlation_matrix[i, :])
            correlations[i] = 0.0  # Remove self-correlation
            
            network_features[1, i] = mean(correlations)  # Average correlation
            network_features[2, i] = maximum(correlations)  # Max correlation
            network_features[3, i] = std(correlations)   # Correlation variability
        end
    end
    
    # Combine expression and network features
    enhanced_features = vcat(log_expression, repeat(network_features, 1, n_samples))
    
    return Float32.(enhanced_features)
end

"""
Enforce biological constraints on predictions
"""
function enforce_biological_constraints(proportions::Matrix, ontology_tree, use_ontology::Bool)
    # Ensure non-negative
    proportions = max.(proportions, 0.0f0)
    
    # Ensure sum to 1 (softmax already does this, but double-check)
    for j in 1:size(proportions, 2)
        col_sum = sum(proportions[:, j])
        if col_sum > 1e-8
            proportions[:, j] ./= col_sum
        else
            proportions[:, j] .= 1.0f0 / size(proportions, 1)  # Uniform if all zeros
        end
    end
    
    # Apply ontology constraints if available
    if use_ontology && ontology_tree !== nothing
        proportions = apply_ontology_constraints(proportions, ontology_tree)
    end
    
    return proportions
end

"""
Apply ontology-based constraints to proportions
"""
function apply_ontology_constraints(proportions::Matrix, ontology_tree)
    # Simplified ontology constraint enforcement
    # Real implementation would use ontology_tree structure
    
    # For now, just ensure consistency between related cell types
    # This is a placeholder for more sophisticated ontology-based constraints
    
    return proportions
end

"""
Biological loss function with ontology constraints
"""
function biological_loss_and_gradients(model::OntologyEnhancedGNN, X::Matrix, y::Matrix)
    gradients = gradient(model) do m
        biological_enhanced_loss(m, X, y)
    end
    
    loss_val = biological_enhanced_loss(model, X, y)
    return loss_val, gradients[1]
end

function biological_enhanced_loss(model::OntologyEnhancedGNN, X::Matrix, y::Matrix)
    predictions = predict_ontology_enhanced_gnn(model, X)
    
    # Main MSE loss
    mse_loss = Flux.mse(predictions, y)
    
    # Biological constraints
    sum_constraint = mean(abs.(sum(predictions, dims=1) .- 1.0f0))
    non_negative_constraint = mean(max.(-predictions, 0.0f0))
    
    # Ontology consistency
    hierarchy_constraint = model.use_ontology ? calculate_ontology_consistency_loss(predictions, model.ontology_tree) : 0.0f0
    
    # Biological plausibility (smooth predictions)
    smoothness_constraint = calculate_smoothness_constraint(predictions)
    
    # Combined loss with biological weighting
    λ_sum = 0.1f0
    λ_nonneg = 0.1f0  
    λ_hier = model.use_ontology ? 0.05f0 : 0.0f0
    λ_smooth = 0.02f0
    
    total_loss = mse_loss + λ_sum * sum_constraint + λ_nonneg * non_negative_constraint + 
                λ_hier * hierarchy_constraint + λ_smooth * smoothness_constraint
    
    return total_loss
end

"""
Calculate ontology consistency loss
"""
function calculate_ontology_consistency_loss(predictions::Matrix, ontology_tree)
    # Simplified ontology consistency
    # Real implementation would use ontology_tree structure to enforce hierarchy
    
    # For now, penalize if related cell types have very different predictions
    consistency_loss = 0.0f0
    
    # Example: T cell subtypes should have similar patterns
    # This is a placeholder for real ontology-based consistency
    
    return consistency_loss
end

"""
Calculate smoothness constraint to encourage biologically plausible predictions
"""
function calculate_smoothness_constraint(predictions::Matrix)
    # Penalize extreme predictions (too close to 0 or 1)
    extreme_penalty = mean(predictions .^ 2 .* (1.0f0 .- predictions) .^ 2)
    
    # Penalize high variance across samples (unless biologically justified)
    variance_penalty = mean(var(predictions, dims=2))
    
    return extreme_penalty + 0.1f0 * variance_penalty
end

# Helper functions for evaluation

function evaluate_enhanced_model(model::OntologyEnhancedGNN, X::Matrix, y::Matrix)
    predictions = predict_ontology_enhanced_gnn(model, X)
    return Flux.mse(predictions, y)
end

function calculate_enhanced_correlation(model::OntologyEnhancedGNN, X::Matrix, y::Matrix)
    predictions = predict_ontology_enhanced_gnn(model, X)
    
    correlations = []
    for i in 1:size(predictions, 1)
        if var(predictions[i, :]) > 1e-10 && var(y[i, :]) > 1e-10
            push!(correlations, cor(predictions[i, :], y[i, :]))
        else
            push!(correlations, 0.0)
        end
    end
    
    return mean(correlations)
end

function calculate_enhanced_rmse(model::OntologyEnhancedGNN, X::Matrix, y::Matrix)
    predictions = predict_ontology_enhanced_gnn(model, X)
    return sqrt(Flux.mse(predictions, y))
end

function prepare_training_data(X_reference::Matrix, y_reference::Vector{String}, 
                              X_mixture::Matrix, y_mixture::Matrix, cell_types::Vector{String})
    # For now, use mixture data for training
    # In real implementation, would create more sophisticated training strategy
    return Float32.(X_mixture), Float32.(y_mixture)
end
