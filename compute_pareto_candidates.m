
function pareto = compute_pareto_candidates(models, settings)
%COMPUTE_PARETO_CANDIDATES Random feasible sampling for a simple
%Pareto-style trade-off view.
%
% This is not the main optimizer. PSO remains the primary optimization
% engine. The Pareto-style sampling is only used to visualize trade-offs
% between Rz, Rt, and tool wear.

    rng(settings.tradeoff.seed, 'twister');

    nSamples = settings.tradeoff.nSamples;
    lb = settings.bounds.lb(:)';
    ub = settings.bounds.ub(:)';

    X = repmat(lb, nSamples, 1) + rand(nSamples, numel(lb)) .* repmat((ub - lb), nSamples, 1);

    Rt = predict_Rt(models, X);
    Rz = predict_Rz(models, X);
    TW = predict_ToolWear(models, X);

    J = nan(nSamples, 1);
    for i = 1:nSamples
        J(i) = objective_function(X(i, :), models, settings);
    end

    responseMatrix = [Rz, Rt, TW];
    isFront = is_pareto_efficient(responseMatrix);

    allTable = table(X(:,1), X(:,2), X(:,3), Rt, Rz, TW, J, isFront, ...
        'VariableNames', {'Vc', 'f', 'DOC', 'Rt_pred', 'Rz_pred', 'ToolWear_pred', 'Objective', 'IsParetoFront'});

    frontTable = allTable(allTable.IsParetoFront, :);

    pareto = struct();
    pareto.all = allTable;
    pareto.front = frontTable;
end
