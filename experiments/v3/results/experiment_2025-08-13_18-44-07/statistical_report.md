# Statistical Comparison Report

## Significant Differences (α = 0.05 with correction)

| Method 1 | Method 2 | Metric | p-value | Corrected p-value | Effect Size | 95% CI |
|----------|----------|--------|---------|-------------------|-------------|--------|
| Linear_NNLS | GNN_Ontology | proportion_constraint_violation | 0.0034 | 0.0202 | 2.79 | (0.0, 0.0) |
| Linear_NNLS | Random_Forest | proportion_constraint_violation | 0.0 | 0.0 | 15.839 | (0.0, 0.0) |
| Linear_NNLS | GNN_Flat | proportion_constraint_violation | 0.0005 | 0.0028 | 4.7 | (0.0, 0.0) |
| GNN_Ontology | Random_Forest | proportion_constraint_violation | 0.0001 | 0.0003 | 8.171 | (0.0, 0.0) |
| Random_Forest | GNN_Flat | proportion_constraint_violation | 0.0 | 0.0002 | -8.736 | (-0.0, -0.0) |

## All Comparisons

| Method 1 | Method 2 | Metric | p-value | Corrected p-value | Effect Size | Significant |
|----------|----------|--------|---------|-------------------|-------------|-------------|
| Linear_NNLS | GNN_Ontology | proportion_constraint_violation | 0.0034 | 0.0202 | 2.79 | ✓ |
| Linear_NNLS | Random_Forest | proportion_constraint_violation | 0.0 | 0.0 | 15.839 | ✓ |
| Linear_NNLS | GNN_Flat | proportion_constraint_violation | 0.0005 | 0.0028 | 4.7 | ✓ |
| GNN_Ontology | Random_Forest | proportion_constraint_violation | 0.0001 | 0.0003 | 8.171 | ✓ |
| GNN_Ontology | GNN_Flat | proportion_constraint_violation | 0.1233 | 0.7395 | 0.871 | ✗ |
| Random_Forest | GNN_Flat | proportion_constraint_violation | 0.0 | 0.0002 | -8.736 | ✓ |
