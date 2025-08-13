using DecisionTree
using Statistics

"""
Random Forest Baseline for Cell Type Deconvolution
This provides a non-linear baseline to compare against
"""

struct RandomForestDeconvolutionModel
    models::Vector{Any}  # One model per cell type
    cell_type_names::Vector{String}
    feature_names::Vector{String}
    n_trees::Int
    max_depth::Int
end

function train_random_forest_deconvolution(X_reference::Matrix, y_reference::Vector{String};
                                           n_trees=50, max_depth=8, min_samples_split=5)
    """
    Train random forest for deconvolution using DecisionTree.jl
    Uses one-vs-rest approach: one classifier per cell type
    """

    cell_types = unique(y_reference)
    n_features = size(X_reference, 1)
    feature_names = ["Gene_$i" for i in 1:n_features]

    # Train one classifier per cell type
    models = []

    for cell_type in cell_types
        # Create binary labels (1 if this cell type, 0 otherwise)
        binary_labels = [y == cell_type ? 1.0 : 0.0 for y in y_reference]

        try
            # Train random forest classifier for this cell type
            # X_reference needs to be transposed for DecisionTree.jl (samples x features)
            X_train = X_reference'  # Transpose to (samples, features)

            # Build random forest
            forest = build_forest(binary_labels, X_train;
                                  n_subfeatures=-1,  # Use sqrt(n_features) 
                                  n_trees=n_trees,
                                  max_depth=max_depth,
                                  min_samples_split=min_samples_split)

            push!(models, forest)

        catch e
            @warn "Failed to train RF for cell type $cell_type: $e"
            # Use a dummy model that returns 0.1 for this cell type
            push!(models, nothing)
        end
    end

    return RandomForestDeconvolutionModel(models,
                                          cell_types,
                                          feature_names,
                                          n_trees,
                                          max_depth)
end

function predict_random_forest_deconvolution(model::RandomForestDeconvolutionModel,
                                             X_mixture::Matrix)
    """
    Predict cell type proportions using trained random forest models
    """

    n_mixtures = size(X_mixture, 2)
    n_cell_types = length(model.cell_type_names)

    # Initialize predictions
    predictions = zeros(n_cell_types, n_mixtures)

    # Get predictions from each binary classifier
    X_test = X_mixture'  # Transpose to (samples, features)

    for (i, forest) in enumerate(model.models)
        if forest !== nothing
            try
                # Get predictions for this cell type
                probs = apply_forest_proba(forest, X_test, [0.0, 1.0])
                # Take probability of positive class (class 1.0)
                predictions[i, :] = probs[:, 2]  # Second column is prob of class 1.0
            catch e
                @warn "Failed to predict with RF for cell type $(model.cell_type_names[i]): $e"
                predictions[i, :] .= 0.1  # Default prediction
            end
        else
            predictions[i, :] .= 0.1  # Default for failed models
        end
    end

    # Normalize predictions to sum to 1 (proportions constraint)
    for j in 1:n_mixtures
        total = sum(predictions[:, j])
        if total > 0
            predictions[:, j] ./= total
        else
            # If all predictions are 0, use uniform distribution
            predictions[:, j] .= 1.0 / n_cell_types
        end
    end

    return predictions
end

"""
Feature importance analysis for Random Forest
"""
function analyze_rf_feature_importance(model::RandomForestDeconvolutionModel)
    """
    Extract feature importance from trained random forest models
    Note: DecisionTree.jl doesn't provide feature importance directly,
    so this is a placeholder for future implementation
    """

    @warn "Feature importance analysis not implemented for DecisionTree.jl"

    # Return empty dictionary as placeholder
    return Dict{String,Vector{String}}()
end

"""
Simple evaluation function for Random Forest model
"""
function evaluate_rf_model(model::RandomForestDeconvolutionModel, X_test::Matrix,
                           y_true::Matrix)
    """
    Evaluate random forest model performance
    """

    y_pred = predict_random_forest_deconvolution(model, X_test)

    # Calculate correlation per cell type
    correlations = []
    for i in 1:size(y_true, 1)
        corr = cor(y_true[i, :], y_pred[i, :])
        push!(correlations, isnan(corr) ? 0.0 : corr)
    end

    return Dict("mean_correlation" => mean(correlations),
                "correlations_per_type" => correlations,
                "predictions" => y_pred)
end

"""
Simpler Random Forest implementation using DecisionTree.jl
"""
function simple_rf_deconvolution(X_reference::Matrix, y_reference::Vector{String},
                                 X_mixture::Matrix;
                                 n_trees=100, max_depth=10)
    """
    Simple random forest implementation for quick testing
    """

    cell_types = unique(y_reference)
    n_cell_types = length(cell_types)
    n_samples = size(X_mixture, 2)
    proportions = zeros(n_cell_types, n_samples)

    X_train = transpose(X_reference)
    X_test = transpose(X_mixture)

    for (i, cell_type) in enumerate(cell_types)
        # Create binary target
        y_binary = [label == cell_type ? 1.0 : 0.0 for label in y_reference]

        # Train random forest using correct DecisionTree.jl API
        # build_forest(labels, features, n_subfeatures, n_trees, partial_sampling, max_depth, min_samples_leaf, min_samples_split, min_purity_increase)
        rf = build_forest(y_binary, X_train,
                          -1,        # n_subfeatures: -1 means use all features
                          n_trees,   # n_trees
                          0.7,       # partial_sampling
                          max_depth, # max_depth
                          1,         # min_samples_leaf
                          2,         # min_samples_split
                          0.0)       # min_purity_increase

        # Predict
        predictions = apply_forest(rf, X_test)
        proportions[i, :] = predictions
    end

    # Normalize proportions
    proportions = max.(proportions, 0.0)

    for j in 1:n_samples
        sample_sum = sum(proportions[:, j])
        if sample_sum > 0
            proportions[:, j] = proportions[:, j] / sample_sum
        else
            proportions[:, j] .= 1.0 / n_cell_types
        end
    end

    return proportions
end
