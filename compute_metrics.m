
function metrics = compute_metrics(yTrue, yPred)
%COMPUTE_METRICS Calculate R^2, RMSE, and MAE for model assessment.

    yTrue = yTrue(:);
    yPred = yPred(:);

    residual = yTrue - yPred;
    sse = sum(residual.^2, 'omitnan');
    sst = sum((yTrue - mean(yTrue, 'omitnan')).^2, 'omitnan');

    metrics = struct();
    metrics.R2 = 1 - sse / max(sst, eps);
    metrics.RMSE = sqrt(mean(residual.^2, 'omitnan'));
    metrics.MAE = mean(abs(residual), 'omitnan');
end
