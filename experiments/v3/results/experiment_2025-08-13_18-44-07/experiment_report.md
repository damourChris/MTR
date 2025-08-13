# Cell Type Deconvolution Experiment Report

**Experiment Date:** 2025-08-13_18-44-07

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
| 1 | Linear_NNLS | 0.0023 | 0.0115 |
| 2 | GNN_Ontology | 0.0021 | 0.0225 |
| 3 | GNN_Flat | 0.0017 | 0.0156 |
| 4 | Random_Forest | 0.0 | 0.0 |

### Detailed Performance Metrics

#### Linear_NNLS

| Metric | Mean | Std | Median |
|--------|------|-----|--------|
| mean_pearson | 0.0023 | 0.0115 | -0.0027 |
| overall_rmse | 0.1704 | 0.0028 | 0.1705 |
| overall_mae | 0.1274 | 0.0014 | 0.1271 |
| detection_accuracy | 0.3162 | 0.0089 | 0.3195 |

#### GNN_Ontology

| Metric | Mean | Std | Median |
|--------|------|-----|--------|
| mean_pearson | 0.0021 | 0.0225 | 0.0066 |
| overall_rmse | 0.1769 | 0.0033 | 0.1769 |
| overall_mae | 0.1287 | 0.0018 | 0.1288 |
| detection_accuracy | 0.3323 | 0.0086 | 0.3345 |

#### CIBERSORTx_Style

| Metric | Mean | Std | Median |
|--------|------|-----|--------|

#### Random_Forest

| Metric | Mean | Std | Median |
|--------|------|-----|--------|
| mean_pearson | 0.0 | 0.0 | 0.0 |
| overall_rmse | 0.1865 | 0.0026 | 0.1863 |
| overall_mae | 0.1306 | 0.0009 | 0.1303 |
| detection_accuracy | 0.3162 | 0.0089 | 0.3195 |

#### GNN_Flat

| Metric | Mean | Std | Median |
|--------|------|-----|--------|
| mean_pearson | 0.0017 | 0.0156 | 0.006 |
| overall_rmse | 0.1878 | 0.0032 | 0.1875 |
| overall_mae | 0.1311 | 0.0018 | 0.1312 |
| detection_accuracy | 0.3995 | 0.0078 | 0.4018 |

