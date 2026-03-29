
function [J, detail] = objective_function(x, models, settings)
%OBJECTIVE_FUNCTION Weighted normalized objective used by PSO.
%
% J = w1*norm(Rz) + w2*norm(Rt) + w3*norm(ToolWear)
%
% Normalization uses the min/max values seen in the experimental dataset.
% This keeps the three response scales comparable.

    if size(x, 1) ~= 1
        error('objective_function expects a single 1x3 candidate point.');
    end

    x = double(x(:))';
    lb = settings.bounds.lb;
    ub = settings.bounds.ub;

    % Strict feasible-domain enforcement
    x = min(max(x, lb), ub);

    RtPred = predict_Rt(models, x);
    RzPred = predict_Rz(models, x);
    TWPred = predict_ToolWear(models, x);

    RtNorm = normalize_value(RtPred, models.Rt.y, settings.objective.clampBelowZero);
    RzNorm = normalize_value(RzPred, models.Rz.y, settings.objective.clampBelowZero);
    TWNorm = normalize_value(TWPred, models.ToolWear.y, settings.objective.clampBelowZero);

    w = [ ...
        settings.objective.weights.Rz, ...
        settings.objective.weights.Rt, ...
        settings.objective.weights.ToolWear];

    J = w * [RzNorm; RtNorm; TWNorm];

    detail = struct();
    detail.x = x;
    detail.Rt = RtPred;
    detail.Rz = RzPred;
    detail.ToolWear = TWPred;
    detail.RtNorm = RtNorm;
    detail.RzNorm = RzNorm;
    detail.ToolWearNorm = TWNorm;
end

function z = normalize_value(value, yData, clampBelowZero)
    yMin = min(yData);
    yMax = max(yData);
    z = (value - yMin) / max(yMax - yMin, eps);

    if clampBelowZero
        z = max(z, 0);
    end
end
