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
