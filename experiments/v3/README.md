# Cell Type Deconvolution: Rigorous Experimental Framework (v3)

## Overview
This version implements a scientifically rigorous approach to evaluate whether ontology-guided graph neural networks provide advantages for cell type deconvolution compared to established methods.

## Key Improvements from v2
1. **Fixed technical implementation** (proper loss functions, evaluation metrics)
2. **Comprehensive baselines** (linear regression, CIBERSORTx-style, random forest)
3. **Proper evaluation framework** (correlation, RMSE, MAE, proportion constraints)
4. **Ablation studies** (ontology vs. no ontology)
5. **Real data validation** (not just synthetic)
6. **Statistical significance testing**

## Experimental Design

### Primary Research Question
**Does ontology-guided graph neural network architecture provide statistically significant improvements over established linear methods for bulk RNA-seq cell type deconvolution?**

### Hypotheses
- **H0**: Ontology-guided GNN performs ≤ linear baselines
- **H1**: Ontology-guided GNN performs > linear baselines (with statistical significance)

### Methods Comparison
1. **Linear Regression Baseline** (NNLS)
2. **CIBERSORTx-style** (Support Vector Regression)
3. **Random Forest Baseline**
4. **GNN without Ontology** (flat graph)
5. **GNN with Ontology** (hierarchical graph)

### Evaluation Metrics
- **Pearson correlation** per cell type
- **Spearman correlation** per cell type  
- **Root Mean Squared Error** (RMSE)
- **Mean Absolute Error** (MAE)
- **Proportion constraint violation** (|sum - 1|)

### Statistical Testing
- **Paired t-tests** for method comparisons
- **Bonferroni correction** for multiple testing
- **Effect size calculation** (Cohen's d)
- **Cross-validation** with biological replicates

## File Structure
```
v3/
├── README.md                    # This file
├── config.jl                   # Experiment configuration
├── main.jl                     # Main experimental pipeline
├── baselines/
│   ├── linear_regression.jl    # NNLS baseline
│   ├── cibersortx_style.jl     # SVR baseline
│   └── random_forest.jl        # RF baseline
├── evaluation/
│   ├── metrics.jl              # Evaluation metrics
│   ├── statistical_tests.jl    # Statistical testing
│   └── visualization.jl        # Results plotting
├── models/
│   ├── gnn_fixed.jl            # Fixed GNN implementation
│   └── gnn_utils.jl            # GNN utilities
└── data/
    └── preprocessing.jl         # Data preprocessing
```

## Usage
```julia
include("main.jl")
results = run_comprehensive_experiment()
```

This will run all baselines, perform statistical testing, and generate comprehensive evaluation reports.
