# Cell Type Deconvolution Experiment Report

**Experiment Date:** 2025-08-13_18-48-44

## Experimental Setup

- **Cross-validation folds:** 5
- **Random seed:** 42
- **Significance level:** 0.05
- **Multiple testing correction:** bonferroni

## Methods Compared

- **Linear_NNLS**
- **GNN_Ontology**
- **CIBERSORTx_Style**
- **Random_Forest**
- **GNN_Flat**

## Results Summary

### Overall Performance Ranking (by Mean Pearson Correlation)

| Rank | Method | Mean Pearson Correlation | Std |
|------|--------|-------------------------|-----|
| 1 | Linear_NNLS | 0.9959 | 0.0005 |
| 2 | Random_Forest | 0.6571 | 0.026 |
| 3 | GNN_Ontology | 0.0593 | 0.0217 |
| 4 | GNN_Flat | 0.0284 | 0.0161 |

### Detailed Performance Metrics

#### Linear_NNLS

| Metric | Mean | Std | Median |
|--------|------|-----|--------|
| mean_pearson | 0.9959 | 0.0005 | 0.9962 |
| overall_rmse | 0.0193 | 0.0018 | 0.019 |
| overall_mae | 0.0065 | 0.0004 | 0.0066 |
| detection_accuracy | 0.9428 | 0.0016 | 0.9427 |

#### GNN_Ontology

| Metric | Mean | Std | Median |
|--------|------|-----|--------|
| mean_pearson | 0.0593 | 0.0217 | 0.0635 |
| overall_rmse | 0.1743 | 0.0033 | 0.1742 |
| overall_mae | 0.1267 | 0.0017 | 0.1267 |
| detection_accuracy | 0.3367 | 0.009 | 0.3395 |

#### CIBERSORTx_Style

| Metric | Mean | Std | Median |
|--------|------|-----|--------|

#### Random_Forest

| Metric | Mean | Std | Median |
|--------|------|-----|--------|
| mean_pearson | 0.6571 | 0.026 | 0.6674 |
| overall_rmse | 0.1884 | 0.0088 | 0.1848 |
| overall_mae | 0.0955 | 0.0018 | 0.0949 |
| detection_accuracy | 0.7064 | 0.0184 | 0.7014 |

#### GNN_Flat

| Metric | Mean | Std | Median |
|--------|------|-----|--------|
| mean_pearson | 0.0284 | 0.0161 | 0.0316 |
| overall_rmse | 0.1859 | 0.0032 | 0.1855 |
| overall_mae | 0.1296 | 0.0018 | 0.1297 |
| detection_accuracy | 0.4059 | 0.009 | 0.4091 |

