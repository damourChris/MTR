# Experimental Configuration
# This file contains all configuration parameters for the rigorous experimental framework

begin
    # Data paths
    data_base_path = "/home/damourchris/MTR/experiments/v3/data"
    results_path = "/home/damourchris/MTR/experiments/v3/results"

    # Reference datasets (using v2 preprocessed data for now)
    reference_data_path = "/home/damourchris/MTR/experiments/v2/data"
    reference_files = ["GSE22886-GPL96_processed.rds",
                       "GSE22886-GPL97_processed.rds"]

    # Experimental parameters
    random_seed = 42
    n_folds = 5  # Cross-validation folds
    n_bootstrap = 100  # Bootstrap samples for confidence intervals
    test_size = 0.2  # Proportion for test set

    # Statistical testing
    alpha_level = 0.05  # Significance level
    multiple_testing_correction = "bonferroni"

    # Model hyperparameters
    gnn_config = (hidden_dim=128,  # Increased for real data complexity
                  n_layers=3,
                  dropout=0.3,
                  learning_rate=1e-3,
                  epochs=1000,
                  early_stopping_patience=100,

                  # New parameters for real implementation
                  correlation_threshold=0.3,  # For gene graph construction
                  max_edges_per_gene=15,     # Limit graph density
                  n_training_mixtures=2000,   # Number of synthetic training samples
                  mixture_noise_level=0.1,   # Noise level for synthetic mixtures
                  batch_size=32,             # Mini-batch size for training

                  # Feature engineering parameters
                  use_gpu=true,              # Use GPU if available
                  gene_feature_dim=10,       # Dimension of gene features
                  random_seed=42,
                  test_size=0.2)

    # Baseline configurations
    linear_config = (regularization="l2",
                     alpha=0.01)

    rf_config = (n_trees=100,
                 max_depth=10,
                 min_samples_split=5)

    # Evaluation metrics to compute
    metrics_to_compute = ["pearson_correlation",
                          "spearman_correlation",
                          "rmse",
                          "mae",
                          "proportion_constraint_violation",
                          "cell_type_specific_accuracy"]

    # Ontology parameters
    ontology_config = (max_parent_limit=10,  # Reduced from 20
                       min_genes_per_term=5,  # Minimum genes required per ontology term
                       base_term="CL_0000988")

    # Synthetic mixture generation
    mixture_config = (n_samples=1000,  # Number of synthetic mixtures
                      n_cell_types_range=(2, 5),  # Range of cell types per mixture (max 5 since we only have 5 cell types)
                      noise_level=0.1,  # Gaussian noise added to expression
                      min_proportion=0.05,  # Minimum cell type proportion
                      max_proportion=0.8)
end
