
function sensitivity = run_sensitivity_analysis(models, psoResults, data, settings)
%RUN_SENSITIVITY_ANALYSIS One-factor-at-a-time sweeps around the optimum.
%
% For each variable:
% - vary it across the permitted range
% - hold the other two at the PSO optimum
% - predict Rt, Rz, tool wear, and objective
%
% A simple engineering ranking is then produced from the change span.

    bestX = psoResults.bestX(:)';
    lb = settings.bounds.lb(:)';
    ub = settings.bounds.ub(:)';
    varNames = settings.bounds.names;

    nSweep = settings.plot.sweepN;

    sweeps = repmat(struct(), 3, 1);
    effectMatrix = nan(3, 4); % columns: Rt, Rz, ToolWear, Objective

    for v = 1:3
        xLine = linspace(lb(v), ub(v), nSweep)';
        Xeval = repmat(bestX, nSweep, 1);
        Xeval(:, v) = xLine;

        Rt = predict_Rt(models, Xeval);
        Rz = predict_Rz(models, Xeval);
        TW = predict_ToolWear(models, Xeval);

        J = nan(nSweep, 1);
        for i = 1:nSweep
            J(i) = objective_function(Xeval(i, :), models, settings);
        end

        sweeps(v).varName = varNames{v};
        sweeps(v).x = xLine;
        sweeps(v).Xeval = Xeval;
        sweeps(v).Rt = Rt;
        sweeps(v).Rz = Rz;
        sweeps(v).ToolWear = TW;
        sweeps(v).Objective = J;

        effectMatrix(v, 1) = max(Rt) - min(Rt);
        effectMatrix(v, 2) = max(Rz) - min(Rz);
        effectMatrix(v, 3) = max(TW) - min(TW);
        effectMatrix(v, 4) = max(J) - min(J);
    end

    allObjectiveValues = [];
    for v = 1:numel(sweeps)
        allObjectiveValues = [allObjectiveValues; sweeps(v).Objective(:)]; %#ok<AGROW>
    end

    responseRanges = [ ...
        max(data.analysisTable.Rt_avg) - min(data.analysisTable.Rt_avg), ...
        max(data.analysisTable.Rz_avg) - min(data.analysisTable.Rz_avg), ...
        max(data.analysisTable.ToolWear_avg) - min(data.analysisTable.ToolWear_avg), ...
        max(allObjectiveValues) - min(allObjectiveValues) + eps];

    normalizedEffects = effectMatrix ./ max(responseRanges, eps);

    responseLabels = {'Rt_avg', 'Rz_avg', 'ToolWear_avg', 'Objective'};
    rankingRows = cell(0, 7);

    for j = 1:numel(responseLabels)
        [sortedVals, idx] = sort(normalizedEffects(:, j), 'descend');
        rankingRows(end+1, :) = {responseLabels{j}, varNames{idx(1)}, varNames{idx(2)}, varNames{idx(3)}, ... %#ok<AGROW>
                                 sortedVals(1), sortedVals(2), sortedVals(3)};
    end

    rankingTable = cell2table(rankingRows, 'VariableNames', { ...
        'Response', 'Rank1', 'Rank2', 'Rank3', ...
        'Rank1Effect', 'Rank2Effect', 'Rank3Effect'});

    sensitivity = struct();
    sensitivity.bestX = bestX;
    sensitivity.sweeps = sweeps;
    sensitivity.effectMatrix = effectMatrix;
    sensitivity.normalizedEffects = normalizedEffects;
    sensitivity.rankingTable = rankingTable;

    writetable(rankingTable, fullfile(settings.tableDir, 'sensitivity_ranking.csv'));

    fprintf('\n--- Sensitivity ranking ---\n');
    disp(rankingTable);
end
