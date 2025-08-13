# Statistical Comparison Report

## Significant Differences (α = 0.05 with correction)

| Method 1 | Method 2 | Metric | p-value | Corrected p-value | Effect Size | 95% CI |
|----------|----------|--------|---------|-------------------|-------------|--------|
| Linear_NNLS | GNN_Ontology | proportion_constraint_violation | 0.0024 | 0.0146 | -3.042 | (-0.0, -0.0) |
| Linear_NNLS | Random_Forest | proportion_constraint_violation | 0.0006 | 0.0038 | 4.332 | (0.0, 0.0) |
| Linear_NNLS | GNN_Flat | proportion_constraint_violation | 0.0064 | 0.0383 | -2.338 | (-0.0, -0.0) |
| GNN_Ontology | Random_Forest | proportion_constraint_violation | 0.0011 | 0.0064 | 3.78 | (0.0, 0.0) |
| Random_Forest | GNN_Flat | proportion_constraint_violation | 0.0003 | 0.0019 | -5.179 | (-0.0, -0.0) |

## All Comparisons

| Method 1 | Method 2 | Metric | p-value | Corrected p-value | Effect Size | Significant |
|----------|----------|--------|---------|-------------------|-------------|-------------|
| Linear_NNLS | GNN_Ontology | proportion_constraint_violation | 0.0024 | 0.0146 | -3.042 | ✓ |
| Linear_NNLS | Random_Forest | proportion_constraint_violation | 0.0006 | 0.0038 | 4.332 | ✓ |
| Linear_NNLS | GNN_Flat | proportion_constraint_violation | 0.0064 | 0.0383 | -2.338 | ✓ |
| GNN_Ontology | Random_Forest | proportion_constraint_violation | 0.0011 | 0.0064 | 3.78 | ✓ |
| GNN_Ontology | GNN_Flat | proportion_constraint_violation | 0.2556 | 1.0 | 0.593 | ✗ |
| Random_Forest | GNN_Flat | proportion_constraint_violation | 0.0003 | 0.0019 | -5.179 | ✓ |
