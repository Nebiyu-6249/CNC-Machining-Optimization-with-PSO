
# PSO Dry CNC Milling Optimization - MATLAB Project

This project is a complete MATLAB case-study workflow for **AI-driven optimization of dry CNC milling of AISI 1050** using **Particle Swarm Optimization (PSO)** as the main optimizer.

## Main features
- Reads the uploaded Excel workbook directly.
- Uses the exact case-study variables:
  - Cutting speed `Vc`
  - Feed rate `f`
  - Depth of cut `DOC`
- Builds clean response variables:
  - `Rt_avg = mean(L, R, X)`
  - `Rz_avg = mean(M, S, Y)`
  - `ToolWear_avg = mean(E:H)`
- Handles mixed headers, decimal commas, and text numerics.
- Fits practical surrogate models with automatic model selection.
- Uses **PSO as the primary optimization method**.
- Repeats PSO across multiple random seeds for stability analysis.
- Generates dark-mode-friendly figures.
- Saves tables, MAT files, and engineering summaries automatically.

## Folder contents
- `main_pso_cnc_optimization.m` - main script
- `load_cnc_case_data.m` - raw workbook import
- `preprocess_cnc_data.m` - cleaning and response construction
- `fit_surrogate_models.m` - fits Rt, Rz, and tool wear surrogate models
- `select_best_model.m` - model selection logic
- `objective_function.m` - weighted normalized optimization objective
- `run_pso_optimization.m` - custom PSO implementation
- `run_stability_analysis.m` - multi-seed PSO stability processing
- `run_sensitivity_analysis.m` - one-factor-at-a-time sensitivity sweeps
- `plot_dark_mode_figures.m` - data, quality, convergence, trade-off, and stability plots
- `plot_response_surfaces.m` - surface and contour plots
- `summarize_results.m` - engineering summary and file export
- Helper functions:
  - `build_design_matrix.m`
  - `compute_metrics.m`
  - `predict_response_model.m`
  - `predict_Rt.m`
  - `predict_Rz.m`
  - `predict_ToolWear.m`
  - `compute_pareto_candidates.m`
  - `is_pareto_efficient.m`
  - `apply_dark_theme.m`
  - `save_figure_dark.m`

## MATLAB version note
A modern MATLAB release is recommended (R2020a or newer is a comfortable target because the project uses `readcell`, `tiledlayout`, and modern graphics functions).

## How to run
1. Open MATLAB.
2. Set the current folder to this project folder.
3. Make sure the Excel file is in the same folder:
   - `Case Study (1) (1) (1).xlsx`
4. Run:

```matlab
main_pso_cnc_optimization
```

## Output folders created automatically
After the script runs, it creates:

- `outputs_pso_cnc_case/figures`
- `outputs_pso_cnc_case/tables`
- `outputs_pso_cnc_case/models`

## Main output files
Typical saved files include:
- `clean_dataset.csv`
- `model_metrics.csv`
- `pso_run_summary.csv`
- `optimum_solution.csv`
- `pareto_candidates.csv`
- `pareto_front.csv`
- `sensitivity_ranking.csv`
- `engineering_summary.txt`
- `surrogate_models.mat`
- `complete_case_study_workspace.mat`

## How to modify the study
### Change objective weights
Edit this section in `main_pso_cnc_optimization.m`:

```matlab
settings.objective.weights.Rz = 0.35;
settings.objective.weights.Rt = 0.35;
settings.objective.weights.ToolWear = 0.30;
```

### Change PSO settings
Edit:

```matlab
settings.pso.swarmSize
settings.pso.maxIter
settings.pso.wStart
settings.pso.wEnd
settings.pso.c1
settings.pso.c2
settings.pso.seeds
```

### Change bounds
Edit:

```matlab
settings.bounds.lb = [613 100 0.1];
settings.bounds.ub = [817 200 0.2];
```

### Change plotting theme
Edit:

```matlab
settings.plot.theme.bg
settings.plot.theme.ax
settings.plot.theme.fg
settings.plot.theme.grid
settings.plot.theme.colors
```

## Notes on modeling
- The code prefers practical polynomial surrogate models first.
- Model choice is based on LOOCV and training metrics:
  - `R^2`
  - `RMSE`
  - `MAE`
- If a model is weak, the script prints warnings instead of hiding the problem.
- A Gaussian Process Regression candidate is tried only when simpler models are poor **and** `fitrgp` is available.

## Predictor usage after fitting
After running the project:

```matlab
load(fullfile('outputs_pso_cnc_case','models','surrogate_models.mat'));

x = [715 150 0.15];

Rt_value = predict_Rt(models, x);
Rz_value = predict_Rz(models, x);
TW_value = predict_ToolWear(models, x);
```

## MRR note
The project does **not** force a true MRR calculation because cutter engagement geometry is not explicitly provided in the workbook. This keeps the study physically honest. The optimization focuses only on:
- `Rt_avg`
- `Rz_avg`
- `ToolWear_avg`

which matches the required case-study focus.
