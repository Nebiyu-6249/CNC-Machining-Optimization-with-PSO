
function stability = run_stability_analysis(psoResults, settings)
%RUN_STABILITY_ANALYSIS Summarize the spread of best solutions across
%multiple PSO runs with different random seeds.

    runTable = psoResults.runTable;

    stability = struct();
    stability.runTable = runTable;

    stability.summary = table( ...
        {'BestObjective'; 'Vc'; 'f'; 'DOC'}, ...
        [mean(runTable.BestObjective); mean(runTable.Vc); mean(runTable.f); mean(runTable.DOC)], ...
        [std(runTable.BestObjective);  std(runTable.Vc);  std(runTable.f);  std(runTable.DOC)], ...
        [min(runTable.BestObjective);  min(runTable.Vc);  min(runTable.f);  min(runTable.DOC)], ...
        [max(runTable.BestObjective);  max(runTable.Vc);  max(runTable.f);  max(runTable.DOC)], ...
        'VariableNames', {'Variable', 'Mean', 'Std', 'Min', 'Max'});

    writetable(stability.summary, fullfile(settings.tableDir, 'pso_stability_summary.csv'));

    fprintf('\n--- PSO stability summary ---\n');
    disp(stability.summary);
end
