# Scientific Review: Cell Type Deconvolution using Graph Neural Networks and Ontology-Guided Hierarchical Representation

## Executive Summary

This thesis project, coded as "MTR" (likely "Mixture Type Recognition"), attempts to address cell type deconvolution in bulk RNA-seq data using graph neural networks (GNNs) guided by cell ontology hierarchies. While the research question is relevant and the ontology-guided approach is novel, the implementation reveals several critical scientific and methodological weaknesses that undermine the validity and rigor of the work.

## Project Overview

### Research Objective
The project aims to predict cell type proportions in bulk RNA-seq samples (mixtures) by leveraging:
1. Reference datasets with pure cell type samples
2. Cell Ontology (CL) hierarchical structure 
3. Graph neural networks for prediction
4. Marker genes identified through statistical analysis

### Methodology Overview
1. **Reference Graph Construction**: Build ontology trees from reference datasets using marker genes
2. **Mixture Graph Generation**: Apply reference graphs to mixture datasets
3. **GNN Training**: Train heterogeneous graph neural networks for proportion prediction
4. **Evaluation**: Assess prediction accuracy on test mixtures

## Critical Scientific Issues

### 1. **FUNDAMENTAL STATISTICAL FLAWS**

#### Marker Gene Selection
- **Threshold Arbitrariness**: ANOVA p-value threshold (0.0001) and Tukey HSD threshold (10e-9) appear arbitrary without justification
- **Multiple Testing**: While FDR correction is applied to ANOVA, the subsequent Tukey analysis lacks proper multiple testing correction
- **Gene Selection Logic**: The frequency-based approach to identify cell-type-specific genes is scientifically questionable:
  ```r
  # This logic is deeply flawed
  if (frequency_table[most_frequent_string] > 1 && 
      all(frequency_table[-which(names(frequency_table) == most_frequent_string)]) == 1)
  ```
  This arbitrary rule has no biological or statistical justification.

#### Expression Data Processing
- **Log Transformation**: `log2(expression_matrix + 1)` is applied without justification for the +1 pseudocount
- **Normalization**: No evidence of proper between-sample normalization (quantile, TMM, etc.)
- **Batch Effects**: No consideration of platform or batch effects across datasets

### 2. **ONTOLOGY INTEGRATION ISSUES**

#### Hierarchical Structure Problems
- **Maximum Parent Limit**: Arbitrary `max_parent_limit=20` parameter with no biological justification
- **Root Node Selection**: Hardcoded to "hematopoietic cell" (CL_0000988) without validation that all cell types are descendants
- **Missing Validation**: No verification that ontology paths are biologically meaningful

#### Graph Construction Flaws
- **Edge Definition**: Unclear biological interpretation of edges between genes and cell types
- **Heterogeneous Graph**: The conversion to GNNHeteroGraph lacks theoretical foundation for why this representation is appropriate

### 3. **MACHINE LEARNING IMPLEMENTATION PROBLEMS**

#### Model Architecture Issues
```julia
# Questionable architecture choices
HeteroGraphConv((:gene, :to, :cell) => SAGEConv(1 => hidden_channels, tanh),
                (:cell, :to, :cell) => SAGEConv(1 => hidden_channels, tanh))
```
- **Feature Dimensionality**: Single-dimensional input features (gene expression, proportions) severely limit model capacity
- **Layer Justification**: No rationale for SAGE convolution choice over other GNN variants
- **Architecture Depth**: Shallow architecture may be insufficient for complex biological relationships

#### Training and Evaluation Flaws
- **Data Splitting**: Simple 80/20 split without stratification or consideration of biological replicates
- **Loss Function**: Cross-entropy loss inappropriate for proportion prediction (should be regression loss)
- **Evaluation Metrics**: No proper evaluation metrics for proportion prediction (MSE, MAE, correlation)
- **Validation**: No cross-validation or proper hyperparameter tuning

### 4. **EXPERIMENTAL DESIGN WEAKNESSES**

#### Dataset Issues
- **Limited Scope**: Only uses GSE22886 as reference, limiting generalizability
- **Platform Differences**: Mixes GPL96 and GPL97 platforms without addressing technical differences
- **Sample Size**: Insufficient analysis of statistical power

#### Synthetic Data Problems
- **Generation Method**: No description of how synthetic mixtures are created
- **Validation**: No validation that synthetic data reflects real biological mixtures
- **Ground Truth**: Unclear how "true" proportions are established

### 5. **CODE QUALITY AND REPRODUCIBILITY**

#### Technical Issues
- **Hardcoded Paths**: Numerous hardcoded file paths reduce reproducibility
- **Error Handling**: Minimal error checking and validation
- **Documentation**: Insufficient comments and documentation
- **Version Control**: No clear versioning strategy for experiments

#### Data Management
- **File Organization**: Inconsistent naming conventions and directory structures
- **Dependency Management**: Complex dependency chain with potential conflicts
- **Data Provenance**: Poor tracking of data transformations and intermediate results

## Missing Critical Components

### 1. **Baseline Comparisons**
- No comparison with established deconvolution methods (CIBERSORTx, EPIC, quanTIseq)
- No comparison with simpler linear regression approaches
- No ablation studies to validate component contributions

### 2. **Biological Validation**
- No validation against flow cytometry or other orthogonal measurements
- No analysis of biological plausibility of predictions
- No discussion of cell type relationships and expected correlations

### 3. **Statistical Rigor**
- No confidence intervals or uncertainty quantification
- No significance testing of improvements over baselines
- No proper statistical modeling of biological variation

### 4. **Generalization Analysis**
- No cross-platform validation
- No analysis of performance across different tissues/conditions
- No study of robustness to missing cell types

## URGENT SCIENTIFIC CORRECTIONS REQUIRED

Based on the author's responses, several fundamental misconceptions need immediate correction:

### 1. **CRITICAL MISUNDERSTANDING**: Existing Methods
The author claims established methods require lab evaluation and cytometry. **THIS IS FALSE.**

**Reality Check**:
- CIBERSORTx, EPIC, quanTIseq are ALL purely computational
- They use publicly available reference datasets (same as this work)
- No cytometry required for deconvolution
- They already support "one-shot" analysis

**IMPLICATION**: The claimed novelty doesn't exist.

### 2. **MISSING THEORETICAL FOUNDATION**
The author hasn't provided mathematical or biological justification for why:
- Graph convolutions should outperform linear algebra
- Ontology structure adds value beyond reference signatures
- Heterogeneous graphs are appropriate for this problem

### 3. **UNVALIDATED ASSUMPTIONS**
Critical assumptions lack empirical support:
- That Cell Ontology hierarchy improves deconvolution
- That GNNs can detect unknown cell types (no mechanism shown)
- That synthetic linear mixtures represent biological reality

### 4. **EXPERIMENTAL DESIGN PROBLEMS**
The current approach:
- Uses same synthetic generation for training and testing (circular)
- Lacks comparison with actual state-of-the-art methods
- Has no validation against real mixture datasets with known compositions

## MANDATORY REQUIREMENTS FOR SCIENTIFIC VALIDITY

### Immediate Actions Required:

1. **Implement Baseline Comparisons**
   ```julia
   # MUST compare against:
   # - CIBERSORTx 
   # - EPIC
   # - quanTIseq
   # - Simple linear regression
   ```

2. **Validate Ontology Benefit**
   ```julia
   # MUST test:
   # - GNN with ontology vs without ontology
   # - Hierarchical vs flat gene-cell associations
   ```

3. **Real Data Validation**
   ```julia
   # MUST include:
   # - Flow cytometry validated mixtures
   # - Independent test datasets
   # - Cross-platform validation
   ```

4. **Theoretical Framework**
   - Mathematical derivation of why GNNs are appropriate
   - Information-theoretic analysis of ontology contribution
   - Computational complexity comparison

### Questions for Clarification

Before continuing the review, I need clarification on several critical aspects:

1. **What is the specific biological hypothesis** that justifies using ontology-guided GNNs over established linear methods?

2. **How do you validate** that the ontology structure captures relevant biological relationships for deconvolution?

3. **What is the theoretical advantage** of the heterogeneous graph representation over simpler approaches?

4. **How do you ensure** that synthetic mixtures reflect real biological complexity?

5. **What are the computational requirements** and scalability considerations?

6. **How do you handle cell types** not present in the reference dataset?

### Immediate Fixes Required
1. **Implement proper statistical methods** for marker gene selection with appropriate multiple testing correction
2. **Add comprehensive baseline comparisons** with established deconvolution methods
3. **Fix loss function and evaluation metrics** appropriate for proportion prediction
4. **Implement proper cross-validation** with biological considerations
5. **Add uncertainty quantification** and confidence intervals

### Methodological Enhancements
1. **Validate ontology-based approach** against simpler alternatives
2. **Implement proper normalization** and batch effect correction
3. **Add synthetic data validation** against real mixture experiments
4. **Include biological constraints** (proportions sum to 1, non-negative)
5. **Develop theoretical framework** for why GNNs are appropriate for this problem

### Experimental Rigor
1. **Expand to multiple reference datasets** and platforms
2. **Include negative controls** and edge cases
3. **Perform sensitivity analysis** on key parameters
4. **Add computational efficiency analysis**
5. **Implement reproducible workflows** with proper documentation

## Author Responses and Critical Analysis

The author provided responses to key questions, which I analyze below:

### 1. Research Hypothesis
**Author's Response**: "Established linear deconvolution methods rely on a pre-existing reference gene matrix which is evaluated in lab. The hypothesis is that ontology-guided should outperform in assessing composition in a one shot. This method is also purely in-silico so need for cytometry. This method should also be used for establishing unknown cell type."

**Critical Analysis**: 
- **MAJOR FLAW**: Established methods like CIBERSORTx are ALREADY purely in-silico and don't require cytometry
- **Contradiction**: Claims "one shot" superiority but still requires reference datasets (GSE22886)
- **Unsubstantiated**: No evidence provided that ontology guidance improves upon matrix factorization
- **Unclear**: How exactly would unknown cell types be "detected" without reference signatures?

### 2. Ontology Validation  
**Author's Response**: "The ontology already captures biologically relevant relationships"

**Critical Analysis**:
- **INSUFFICIENT**: This is an assumption, not validation
- **Missing Evidence**: No empirical validation that CL ontology relationships improve deconvolution accuracy
- **Circular Logic**: Assumes what needs to be proven
- **REQUIRED**: Ablation studies comparing ontology-guided vs. flat representations

### 3. Graph Representation Justification
**Author's Response**: "Good questions, they match with ontology?"

**Critical Analysis**:
- **NON-ANSWER**: This doesn't address the theoretical justification
- **Missing Theory**: No explanation of why graph convolutions are superior to linear methods
- **Computational Cost**: GNNs add complexity without demonstrated benefit

### 4. Synthetic Mixture Construction
**Author's Response**: "There are constructed by using reference gene expression for specific cell types and mixing them using linear models"

**Critical Analysis**:
- **STANDARD APPROACH**: This is exactly how existing methods work (not novel)
- **Missing Validation**: No proof that linear mixing reflects biological reality
- **Bias Risk**: Training and testing on same synthetic generation process

### 5. Unknown Cell Type Detection
**Author's Response**: "Ideally these should be able to be detected by the model"

**Critical Analysis**:
- **WISHFUL THINKING**: "Ideally" is not a scientific method
- **No Mechanism**: Current architecture provides no pathway for novel cell type detection
- **Missing Implementation**: Code shows no capability for this claimed feature

## Conclusion

While the research question is important and the ontology-guided approach shows potential novelty, the current implementation suffers from fundamental statistical, methodological, and experimental design flaws that severely compromise its scientific validity. The work requires substantial revision to meet basic standards of computational biology research.

The most concerning issues are:
1. **Arbitrary statistical thresholds** without biological justification
2. **Inappropriate loss functions** for the prediction task
3. **Lack of proper baselines** and validation
4. **Insufficient experimental rigor** in design and evaluation

This thesis would benefit from a ground-up redesign focusing on proper statistical methods, comprehensive validation, and clear biological motivation for the methodological choices.

---

*Assessment completed as of: August 13, 2025*
*Reviewer: Harsh Scientific Critic with GNN Expertise*
