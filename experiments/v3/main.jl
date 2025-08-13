"""
Main Experimental Pipeline for Rigorous Cell Type Deconvolution Evaluation

This runs comprehensive experiments to evaluate the effectiveness of
ontology-guided GNNs compared to established baseline methods.
"""

import Pkg
Pkg.activate(@__DIR__)

include("config.jl")
include("data/preprocessing.jl")
include("baselines/linear_regression.jl")
include("baselines/cibersortx_style.jl")  # New CIBERSORTx baseline
include("baselines/random_forest.jl")
include("models/simple_gnn.jl")  # Real GNN with biological graphs
include("models/ontology_enhanced_gnn_clean.jl")  # Clean ontology-enhanced GNN
include("evaluation/metrics.jl")
include("evaluation/statistical_tests.jl")

using Random
using Statistics
using Dates
using JSON3
using Printf

function run_comprehensive_experiment()
    """
    Run the complete experimental pipeline
    """

    Random.seed!(random_seed)
    timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")

    @info "="^60
    @info "Starting Comprehensive Cell Type Deconvolution Experiment"
    @info "Timestamp: $timestamp"
    @info "="^60

    # Create results directory
    if !isdir(results_path)
        mkdir(results_path)
    end

    experiment_dir = joinpath(results_path, "experiment_$timestamp")
    mkdir(experiment_dir)

    try
        # Step 1: Load and preprocess data
        @info "Step 1: Loading and preprocessing data..."
        X_reference, y_reference = load_and_preprocess_reference_data(reference_data_path,
                                                                      reference_files)
        validate_data_quality(X_reference, y_reference)

        # Step 2: Generate synthetic mixtures
        @info "Step 2: Generating synthetic mixtures..."
        X_mixtures, y_proportions, cell_types = generate_synthetic_mixtures(X_reference,
                                                                            y_reference,
                                                                            mixture_config)

        @info "Generated $(size(X_mixtures, 2)) synthetic mixtures with $(length(cell_types)) cell types"

        # Step 3: Create cross-validation folds
        @info "Step 3: Creating cross-validation splits..."
        cv_folds = split_data_for_cv(X_mixtures, y_proportions, n_folds)

        # Step 4: Run all methods with cross-validation
        @info "Step 4: Running all methods with $n_folds-fold cross-validation..."

        all_cv_results = Dict()

        # # Linear Regression Baseline
        # @info "  Running Linear Regression baseline..."
        # all_cv_results["Linear_NNLS"] = run_linear_baseline_cv(cv_folds, X_reference,
        #                                                        y_reference)

        # # CIBERSORTx-style baseline
        # @info "  Running CIBERSORTx-style baseline..."
        # all_cv_results["CIBERSORTx_Style"] = run_cibersortx_baseline_cv(cv_folds,
        #                                                                 X_reference,
        #                                                                 y_reference)

        # # Random Forest baseline
        # @info "  Running Random Forest baseline..."
        # all_cv_results["Random_Forest"] = run_rf_baseline_cv(cv_folds, X_reference,
        #                                                      y_reference)

        # GNN without ontology
        @info "  Running GNN without ontology..."
        all_cv_results["GNN_Flat"] = run_gnn_baseline_cv(cv_folds, X_reference, y_reference;
                                                         use_ontology=false)

        # GNN with ontology (main method)
        @info "  Running GNN with ontology..."
        all_cv_results["GNN_Ontology"] = run_gnn_baseline_cv(cv_folds, X_reference,
                                                             y_reference; use_ontology=true)

        # Step 5: Aggregate results and perform statistical testing
        @info "Step 5: Performing statistical analysis..."
        aggregated_results = aggregate_cv_results(all_cv_results)

        # Statistical comparisons
        comparisons = compare_all_methods(aggregated_results, metrics_to_compute,
                                          alpha_level, multiple_testing_correction)

        # Step 6: Generate comprehensive report
        @info "Step 6: Generating results report..."
        generate_comprehensive_report(aggregated_results, comparisons, experiment_dir,
                                      timestamp)

        # Step 7: Save raw results
        save_raw_results(all_cv_results, aggregated_results, comparisons, experiment_dir)

        @info "="^60
        @info "Experiment completed successfully!"
        @info "Results saved to: $experiment_dir"
        @info "="^60

        return aggregated_results, comparisons

    catch e
        @error "Experiment failed with error: $e"
        rethrow(e)
    end
end

function run_linear_baseline_cv(cv_folds, X_reference, y_reference)
    """Run linear regression baseline with cross-validation"""

    cv_results = []

    for (fold_idx, fold) in enumerate(cv_folds)
        try
            # Train model
            model = train_linear_deconvolution(X_reference, y_reference;
                                               regularization="nnls")

            # Predict
            y_pred = predict_linear_deconvolution(model, fold.X_test)

            # Evaluate
            results = comprehensive_evaluation(y_pred, fold.y_test)
            results["fold"] = fold_idx

            push!(cv_results, results)

        catch e
            @warn "Linear baseline failed on fold $fold_idx"
        end
    end

    return cv_results
end

function run_cibersortx_baseline_cv(cv_folds, X_reference, y_reference)
    """Run CIBERSORTx-style baseline with cross-validation"""

    cv_results = []

    for (fold_idx, fold) in enumerate(cv_folds)
        try
            # Train model with feature selection
            model = train_cibersortx_style(X_reference, y_reference; n_features=500)

            # Predict
            y_pred = predict_cibersortx_style(model, fold.X_test)

            # Evaluate
            results = comprehensive_evaluation(y_pred, fold.y_test)
            results["fold"] = fold_idx

            push!(cv_results, results)

        catch e
            @warn "CIBERSORTx baseline failed on fold $fold_idx"
        end
    end

    return cv_results
end

function run_rf_baseline_cv(cv_folds, X_reference, y_reference)
    """Run Random Forest baseline with cross-validation"""

    cv_results = []

    for (fold_idx, fold) in enumerate(cv_folds)
        # Use simplified RF implementation
        y_pred = simple_rf_deconvolution(X_reference, y_reference, fold.X_test;
                                         n_trees=rf_config.n_trees,
                                         max_depth=rf_config.max_depth)

        # Evaluate
        results = comprehensive_evaluation(y_pred, fold.y_test)
        results["fold"] = fold_idx

        push!(cv_results, results)
        try
        catch e
            @warn "Random Forest baseline failed on fold $fold_idx: $e"
        end
    end

    return cv_results
end

function run_gnn_baseline_cv(cv_folds, X_reference, y_reference; use_ontology::Bool)
    """Run simplified GNN baseline with cross-validation"""

    cv_results = []

    use_ontology = false

    for (fold_idx, fold) in enumerate(cv_folds)
        # Train simplified GNN model
        model, history = train_simple_gnn(X_reference, y_reference,
                                          fold.X_train, fold.y_train;
                                          use_ontology=use_ontology,
                                          config=gnn_config)

        # Predict
        y_pred = predict_simple_gnn(model, fold.X_test)

        # Evaluate
        results = comprehensive_evaluation(y_pred, fold.y_test)
        results["fold"] = fold_idx
        results["training_history"] = history

        push!(cv_results, results)
        try

        catch e
            @warn "GNN (ontology=$use_ontology) failed on fold $fold_idx"
        end
    end

    return cv_results
end

function aggregate_cv_results(all_cv_results)
    """Aggregate cross-validation results across folds"""

    aggregated = Dict()

    for (method_name, cv_results) in all_cv_results
        if isempty(cv_results)
            @warn "No results for method $method_name"
            continue
        end

        aggregated[method_name] = Dict()

        # Get all metric names from first result
        metric_names = [key
                        for key in keys(cv_results[1])
                        if key != "fold" && key != "training_history"]

        for metric in metric_names
            # Collect values across folds
            values = []
            for result in cv_results
                if haskey(result, metric)
                    value = result[metric]
                    if isa(value, Vector)
                        append!(values, value)
                    elseif isa(value, Matrix)
                        # For matrix values, we might want to compute a summary statistic
                        # For now, skip matrix values in aggregation
                        continue
                    else
                        push!(values, value)
                    end
                end
            end

            if !isempty(values)
                # Remove NaN values (only for scalar values)
                clean_values = []
                for v in values
                    if isa(v, Number) && !isnan(v)
                        push!(clean_values, v)
                    elseif !isa(v, Number)
                        push!(clean_values, v)  # Keep non-numeric values as-is
                    end
                end

                if !isempty(clean_values)
                    metric_str = string(metric)
                    # Only compute statistics for numeric values
                    if all(x -> isa(x, Number), clean_values)
                        aggregated[method_name][metric_str * "_mean"] = mean(clean_values)
                        aggregated[method_name][metric_str * "_std"] = std(clean_values)
                        aggregated[method_name][metric_str * "_median"] = median(clean_values)
                    end
                    aggregated[method_name][metric] = clean_values  # Keep raw values for statistical testing
                end
            end
        end
    end

    return aggregated
end

function generate_comprehensive_report(aggregated_results, comparisons, experiment_dir,
                                       timestamp)
    """Generate comprehensive experimental report"""

    report_file = joinpath(experiment_dir, "experiment_report.md")

    open(report_file, "w") do f
        write(f, "# Cell Type Deconvolution Experiment Report\n\n")
        write(f, "**Experiment Date:** $timestamp\n\n")
        write(f, "## Experimental Setup\n\n")
        write(f, "- **Cross-validation folds:** $n_folds\n")
        write(f, "- **Random seed:** $random_seed\n")
        write(f, "- **Significance level:** $alpha_level\n")
        write(f, "- **Multiple testing correction:** $multiple_testing_correction\n\n")

        write(f, "## Methods Compared\n\n")
        for method_name in keys(aggregated_results)
            write(f, "- **$method_name**\n")
        end
        write(f, "\n")

        write(f, "## Results Summary\n\n")
        write(f, "### Overall Performance Ranking (by Mean Pearson Correlation)\n\n")

        # Rank methods by mean Pearson correlation
        pearson_scores = []
        for (method, results) in aggregated_results
            if haskey(results, "mean_pearson_mean")
                push!(pearson_scores, (method, results["mean_pearson_mean"]))
            end
        end

        sort!(pearson_scores; by=x -> x[2], rev=true)

        write(f, "| Rank | Method | Mean Pearson Correlation | Std |\n")
        write(f, "|------|--------|-------------------------|-----|\n")

        for (rank, (method, score)) in enumerate(pearson_scores)
            std_score = aggregated_results[method]["mean_pearson_std"]
            write(f,
                  "| $rank | $method | $(round(score, digits=4)) | $(round(std_score, digits=4)) |\n")
        end

        write(f, "\n### Detailed Performance Metrics\n\n")

        for (method, results) in aggregated_results
            write(f, "#### $method\n\n")
            write(f, "| Metric | Mean | Std | Median |\n")
            write(f, "|--------|------|-----|--------|\n")

            for metric in
                ["mean_pearson", "overall_rmse", "overall_mae", "detection_accuracy"]
                if haskey(results, metric * "_mean")
                    mean_val = results[metric * "_mean"]
                    std_val = results[metric * "_std"]
                    median_val = results[metric * "_median"]
                    write(f,
                          "| $metric | $(round(mean_val, digits=4)) | $(round(std_val, digits=4)) | $(round(median_val, digits=4)) |\n")
                end
            end
            write(f, "\n")
        end
    end

    # Generate statistical report
    stats_report_file = joinpath(experiment_dir, "statistical_report.md")
    generate_statistical_report(comparisons, stats_report_file)

    @info "Reports generated:"
    @info "  - Main report: $report_file"
    @info "  - Statistical report: $stats_report_file"
end

function save_raw_results(all_cv_results, aggregated_results, comparisons, experiment_dir)
    """Save raw results in JSON format"""

    # Convert results to JSON-serializable format
    json_results = Dict()
    json_results["cv_results"] = Dict()

    for (method, results) in all_cv_results
        json_results["cv_results"][method] = []
        for result in results
            # Ensure result is a dictionary
            if !isa(result, Dict)
                @warn "Skipping non-dictionary result for method $method: $(typeof(result))"
                continue
            end

            json_dict = Dict()
            for (key, value) in result
                if key != "training_history"  # Skip complex objects
                    if isa(value, Vector)
                        # Handle vector values - check if numeric before checking for NaN
                        if eltype(value) <: Number && any(isnan.(value))
                            json_dict[key] = [isnan(v) ? nothing : v for v in value]
                        else
                            json_dict[key] = value
                        end
                    elseif isa(value, Number) && isnan(value)
                        # Handle scalar NaN values
                        json_dict[key] = nothing
                    else
                        # Handle other values
                        json_dict[key] = value
                    end
                end
            end
            push!(json_results["cv_results"][method], json_dict)
        end
    end

    json_results["aggregated"] = Dict()
    for (method, results) in aggregated_results
        json_results["aggregated"][method] = Dict()
        for (key, value) in results
            if isa(value, Vector)
                # Handle vector values - check each element for NaN
                if eltype(value) <: Number && any(isnan.(value))
                    json_results["aggregated"][method][key] = [isnan(v) ? nothing : v
                                                               for v in value]
                else
                    json_results["aggregated"][method][key] = value
                end
            elseif isa(value, Number) && isnan(value)
                json_results["aggregated"][method][key] = nothing
            else
                json_results["aggregated"][method][key] = value
            end
        end
    end

    # Save to file
    results_file = joinpath(experiment_dir, "raw_results.json")
    open(results_file, "w") do f
        return JSON3.print(f, json_results, 2)
    end

    @info "Raw results saved to: $results_file"
end

# Make it easy to run the experiment
if abspath(PROGRAM_FILE) == @__FILE__
    results, comparisons = run_comprehensive_experiment()
end
