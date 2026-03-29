
# Project notes for the uploaded workbook

These notes are included to help with the report discussion.

## Expected model-selection behavior on the uploaded workbook
Using the selection logic in this project and a sanity-check analysis of the uploaded data:

- `Rt_avg` is likely to select a **weighted interaction model**
  - practical and interpretable
  - weighted by replicate repeatability
  - flagged as **weak** because roughness scatter is high

- `Rz_avg` is likely to select a **linear model**
  - chosen as the least-bad practical fit under strict cross-validation
  - also flagged as **weak**
  - this is a signal that the Rz response is noisy relative to the small dataset size

- `ToolWear_avg` is likely to select a **weighted pure quadratic model**
  - strongest of the three response fits
  - uses repeatability weighting from the E:H flank wear measurements

## Engineering interpretation of this behavior
The workbook contains strong repeat scatter in the roughness responses, especially around the repeated center points. That makes the roughness surrogates much less trustworthy than the tool wear surrogate. The MATLAB code therefore:
- reports model metrics explicitly
- warns when cross-validation is weak
- still provides practical predictor functions for optimization and discussion
- keeps PSO as the main optimizer while making the uncertainty visible

## Likely optimum trend with the default weights
With the default weights in `main_pso_cnc_optimization.m`:
- `Rz = 0.35`
- `Rt = 0.35`
- `ToolWear = 0.30`

the optimum tends to move toward:
- **high cutting speed**
- **mid-to-lower feed**
- **low depth of cut**

This should be treated as a **case-study recommendation**, not a universal machining law, because the roughness models are weak and the exact recommendation depends on the selected weights.
