
%% AI-driven optimization of dry CNC milling using PSO
% This script builds practical surrogate models for Rt, Rz, and tool wear
% from the uploaded experimental workbook, then uses Particle Swarm
% Optimization (PSO) to search for the best machining parameters.
%
% Case study:
% - Process: dry CNC milling
% - Work material: AISI 1050
% - Decision variables: Vc, f, DOC
% - Optimization targets: minimize Rz, Rt, and ToolWear
%
% The code is written for a student mechanical engineering project:
% clear structure, reproducible settings, dark-mode plots, and saved results.

clear;
clc;
close all;

fprintf('\n===============================================================\n');
fprintf(' AI-Driven Optimization of Dry CNC Milling using PSO (MATLAB)\n');
fprintf('===============================================================\n');

%% User-editable settings
settings = struct();

% Project / file settings
settings.projectName = 'PSO_Dry_CNC_Milling_AISI1050';
settings.sheetName = 'Sheet1';
settings.inputExcel = 'Case Study (1) (1) (1).xlsx';

% Random seed used before data processing and non-PSO sampling.
settings.masterSeed = 2025;

% Variable bounds (required by the case study)
settings.bounds.names = {'Vc', 'f', 'DOC'};
settings.bounds.units = {'m/min', 'mm/min', 'mm'};
settings.bounds.lb = [613, 100, 0.1];
settings.bounds.ub = [817, 200, 0.2];

% Weighted normalized single-objective formulation:
% J = w1*norm(Rz) + w2*norm(Rt) + w3*norm(ToolWear)
%
% Default choice:
% - Slightly higher combined emphasis on surface finish
% - Tool wear kept close in importance
% You can change these directly for a different trade-off study.
settings.objective.weights.Rz = 0.35;
settings.objective.weights.Rt = 0.35;
settings.objective.weights.ToolWear = 0.30;

% Clamp normalized values below zero.
% This prevents the optimizer from getting extra reward just because a
% surrogate predicts a value slightly below the minimum seen in the data.
settings.objective.clampBelowZero = true;

% Surrogate model selection settings
settings.model.cvMethod = 'LOOCV';
settings.model.rejectR2Hard = -0.25;  % very poor models are rejected
settings.model.warnR2 = 0.05;         % weak model warning threshold
settings.model.ridgeLambdas = logspace(-4, 4, 60);
settings.model.tryGPR = true;         % only used if fitrgp is available

% PSO settings
settings.pso.swarmSize = 40;
settings.pso.maxIter = 120;
settings.pso.wStart = 0.85;   % exploration at the beginning
settings.pso.wEnd   = 0.45;   % more exploitation near the end
settings.pso.c1 = 1.70;       % cognitive coefficient
settings.pso.c2 = 1.90;       % social coefficient
settings.pso.vMaxFraction = 0.20;
settings.pso.tol = 1e-6;
settings.pso.stallIter = 20;
settings.pso.seeds = [11 22 33 44 55 66 77 88 99 111];

% Trade-off / Pareto-style exploration
settings.tradeoff.nSamples = 4000;
settings.tradeoff.seed = 909;

% Plot settings (dark-mode friendly)
settings.plot.saveFigures = true;
settings.plot.saveFigFiles = true;
settings.plot.theme.bg = [0.08, 0.09, 0.11];
settings.plot.theme.ax = [0.12, 0.13, 0.16];
settings.plot.theme.fg = [0.94, 0.95, 0.96];
settings.plot.theme.grid = [0.38, 0.40, 0.45];
settings.plot.theme.colors = [
    0.16 0.74 0.95  % cyan-blue
    1.00 0.60 0.20  % orange
    0.31 0.85 0.55  % green
    0.93 0.42 0.72  % magenta
    0.92 0.82 0.30  % yellow
    0.70 0.70 0.95  % lavender
];
settings.plot.markerSize = 42;
settings.plot.lineWidth = 1.8;
settings.plot.surfaceGridN = 45;
settings.plot.sweepN = 150;

% Output folders
settings.outputRoot = fullfile(pwd, 'outputs_pso_cnc_case');
settings.figureDir = fullfile(settings.outputRoot, 'figures');
settings.tableDir = fullfile(settings.outputRoot, 'tables');
settings.modelDir = fullfile(settings.outputRoot, 'models');

if ~exist(settings.outputRoot, 'dir'); mkdir(settings.outputRoot); end
if ~exist(settings.figureDir, 'dir'); mkdir(settings.figureDir); end
if ~exist(settings.tableDir, 'dir'); mkdir(settings.tableDir); end
if ~exist(settings.modelDir, 'dir'); mkdir(settings.modelDir); end

%% Resolve Excel path
if ~isfile(settings.inputExcel)
    xlsxCandidates = dir('*.xlsx');
    if numel(xlsxCandidates) == 1
        settings.inputExcel = xlsxCandidates(1).name;
        fprintf('Input Excel file not found by default name.\n');
        fprintf('Using detected workbook: %s\n', settings.inputExcel);
    else
        error(['Could not find the Excel workbook. Put the workbook in the ', ...
               'project folder or update settings.inputExcel.']);
    end
end

%% Start reproducible session
rng(settings.masterSeed, 'twister');

%% 1) Load raw workbook cells
raw = load_cnc_case_data(settings.inputExcel, settings.sheetName);

%% 2) Preprocess and build the clean analysis table
data = preprocess_cnc_data(raw, settings);

% Save clean dataset early
writetable(data.analysisTable, fullfile(settings.tableDir, 'clean_dataset.csv'));

%% 3) Fit surrogate models
models = fit_surrogate_models(data, settings);

% Save models
save(fullfile(settings.modelDir, 'surrogate_models.mat'), 'models', 'settings', 'data');

%% 4) Optional Pareto-style candidate exploration
pareto = compute_pareto_candidates(models, settings);

%% 5) Run PSO with multiple seeds
psoResults = run_pso_optimization(models, data, settings);

%% 6) Stability analysis across repeated PSO runs
stability = run_stability_analysis(psoResults, settings);

%% 7) Sensitivity analysis around the optimum
sensitivity = run_sensitivity_analysis(models, psoResults, data, settings);

%% 8) Make and save dark-mode figures
plot_dark_mode_figures(data, models, psoResults, stability, pareto, sensitivity, settings);
plot_response_surfaces(models, psoResults, settings);

%% 9) Summarize results and save final tables / text outputs
results = summarize_results(data, models, psoResults, stability, sensitivity, pareto, settings);

%% 10) Save complete workspace
save(fullfile(settings.outputRoot, 'complete_case_study_workspace.mat'), ...
    'settings', 'raw', 'data', 'models', 'pareto', 'psoResults', 'stability', 'sensitivity', 'results');

%% Final console summary
fprintf('\n===============================================================\n');
fprintf(' FINAL RECOMMENDED MACHINING PARAMETERS (from best PSO run)\n');
fprintf('===============================================================\n');
fprintf('Vc   = %.4f %s\n', psoResults.bestX(1), settings.bounds.units{1});
fprintf('f    = %.4f %s\n', psoResults.bestX(2), settings.bounds.units{2});
fprintf('DOC  = %.4f %s\n', psoResults.bestX(3), settings.bounds.units{3});

fprintf('\nPredicted responses at optimum:\n');
fprintf('Rt_avg       = %.6f um\n', psoResults.bestPred.Rt);
fprintf('Rz_avg       = %.6f um\n', psoResults.bestPred.Rz);
fprintf('ToolWear_avg = %.6f mm\n', psoResults.bestPred.ToolWear);
fprintf('Objective J  = %.6f\n', psoResults.bestObjective);

fprintf('\nSaved output folder:\n%s\n', settings.outputRoot);

fprintf('\nPredictor usage after loading saved models:\n');
fprintf('  load(fullfile(''outputs_pso_cnc_case'',''models'',''surrogate_models.mat''));\n');
fprintf('  x = [715 150 0.15];\n');
fprintf('  Rt_val = predict_Rt(models, x);\n');
fprintf('  Rz_val = predict_Rz(models, x);\n');
fprintf('  TW_val = predict_ToolWear(models, x);\n\n');
