using Statistics
using StatsBase
using LinearAlgebra

"""
Comprehensive evaluation metrics for cell type deconvolution
All functions expect:
- y_pred: predicted proportions (n_cell_types × n_samples)
- y_true: true proportions (n_cell_types × n_samples)
"""

"""Compute Pearson correlation for each cell type across samples"""
function pearson_correlation_per_cell_type(y_pred::Matrix, y_true::Matrix)
    n_cell_types = size(y_pred, 1)
    correlations = zeros(n_cell_types)

    for i in 1:n_cell_types
        if var(y_true[i, :]) > 1e-10  # Avoid division by zero
            correlations[i] = cor(y_pred[i, :], y_true[i, :])
        else
            correlations[i] = NaN
        end
    end

    return correlations
end

"""Compute Spearman correlation for each cell type across samples"""
function spearman_correlation_per_cell_type(y_pred::Matrix, y_true::Matrix)
    n_cell_types = size(y_pred, 1)
    correlations = zeros(n_cell_types)

    for i in 1:n_cell_types
        if length(unique(y_true[i, :])) > 1  # Need variability for correlation
            correlations[i] = corspearman(y_pred[i, :], y_true[i, :])
        else
            correlations[i] = NaN
        end
    end

    return correlations
end

"""Compute RMSE for each cell type"""
function rmse_per_cell_type(y_pred::Matrix, y_true::Matrix)
    return sqrt.(mean((y_pred - y_true) .^ 2; dims=2))[:, 1]
end

"""Compute MAE for each cell type"""
function mae_per_cell_type(y_pred::Matrix, y_true::Matrix)
    return mean(abs.(y_pred - y_true); dims=2)[:, 1]
end

"""Compute overall RMSE across all predictions"""
function overall_rmse(y_pred::Matrix, y_true::Matrix)
    return sqrt(mean((y_pred - y_true) .^ 2))
end

"""Compute overall MAE across all predictions"""
function overall_mae(y_pred::Matrix, y_true::Matrix)
    return mean(abs.(y_pred - y_true))
end

"""Measure how much predicted proportions violate sum-to-1 constraint"""
function proportion_constraint_violation(y_pred::Matrix)
    sample_sums = sum(y_pred; dims=1)
    return mean(abs.(sample_sums .- 1))
end

"""Measure proportion of negative predictions (biologically invalid)"""
function negative_proportion_violation(y_pred::Matrix)
    return mean(y_pred .< 0)
end

"""
Accuracy of detecting presence/absence of cell types
threshold: minimum proportion to consider a cell type as 'present'
"""
function cell_type_detection_accuracy(y_pred::Matrix, y_true::Matrix, threshold=0.01)
    y_pred_binary = y_pred .> threshold
    y_true_binary = y_true .> threshold

    return mean(y_pred_binary .== y_true_binary)
end

"""
Compute all evaluation metrics and return structured results
"""
function comprehensive_evaluation(y_pred::Matrix, y_true::Matrix;
                                  cell_type_names=nothing, sample_names=nothing)

    # Ensure non-negative predictions for biological validity
    y_pred_clipped = max.(y_pred, 0.0)

    # Normalize predictions to sum to 1 (if needed)
    sample_sums = sum(y_pred_clipped; dims=1)
    y_pred_normalized = y_pred_clipped ./ sample_sums

    results = Dict()

    # Per-cell-type metrics
    results["pearson_correlations"] = pearson_correlation_per_cell_type(y_pred_normalized,
                                                                        y_true)
    results["spearman_correlations"] = spearman_correlation_per_cell_type(y_pred_normalized,
                                                                          y_true)
    results["rmse_per_cell_type"] = rmse_per_cell_type(y_pred_normalized, y_true)
    results["mae_per_cell_type"] = mae_per_cell_type(y_pred_normalized, y_true)

    # Overall metrics
    results["overall_rmse"] = overall_rmse(y_pred_normalized, y_true)
    results["overall_mae"] = overall_mae(y_pred_normalized, y_true)
    results["mean_pearson"] = nanmean(results["pearson_correlations"])
    results["mean_spearman"] = nanmean(results["spearman_correlations"])

    # Constraint violations
    results["proportion_constraint_violation"] = proportion_constraint_violation(y_pred_normalized)
    results["negative_proportion_violation"] = negative_proportion_violation(y_pred)
    results["detection_accuracy"] = cell_type_detection_accuracy(y_pred_normalized, y_true)

    # Additional metrics
    results["median_pearson"] = nanmedian(results["pearson_correlations"])
    results["std_pearson"] = nanstd(results["pearson_correlations"])

    return results
end

"""Mean ignoring NaN values"""
function nanmean(x)
    valid_indices = .!isnan.(x)
    return length(x[valid_indices]) > 0 ? mean(x[valid_indices]) : NaN
end

"""Median ignoring NaN values"""
function nanmedian(x)
    valid_indices = .!isnan.(x)
    return length(x[valid_indices]) > 0 ? median(x[valid_indices]) : NaN
end

"""Standard deviation ignoring NaN values"""
function nanstd(x)
    valid_indices = .!isnan.(x)
    return length(x[valid_indices]) > 1 ? std(x[valid_indices]) : NaN
end

"""
Format evaluation results for display
"""
function format_results(results::Dict, method_name::String)
    println("="^50)
    println("Results for: $method_name")
    println("="^50)
    println("Overall Performance:")
    println("  Mean Pearson Correlation: $(round(results["mean_pearson"], digits=4))")
    println("  Mean Spearman Correlation: $(round(results["mean_spearman"], digits=4))")
    println("  Overall RMSE: $(round(results["overall_rmse"], digits=4))")
    println("  Overall MAE: $(round(results["overall_mae"], digits=4))")
    println("  Detection Accuracy: $(round(results["detection_accuracy"], digits=4))")
    println("\nConstraint Violations:")
    println("  Proportion Sum Violation: $(round(results["proportion_constraint_violation"], digits=6))")
    println("  Negative Proportion Rate: $(round(results["negative_proportion_violation"], digits=6))")
    return println("="^50)
end
