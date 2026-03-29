
function models = fit_surrogate_models(data, settings)
%FIT_SURROGATE_MODELS Fit predictive models for Rt_avg, Rz_avg, and
%ToolWear_avg using practical interpretable models first.
%
% The function prints the selected model for each response and returns
% callable function handles plus training / cross-validation summaries.

    models = struct();

    responseDefs = {
        'Rt',        'Rt_avg',        'Rt_std',        'Rt_avg';
        'Rz',        'Rz_avg',        'Rz_std',        'Rz_avg';
        'ToolWear',  'ToolWear_avg',  'ToolWear_std',  'ToolWear_avg'
    };

    metricRows = cell(0, 10);

    for i = 1:size(responseDefs, 1)
        fieldName   = responseDefs{i, 1};
        responseVar = responseDefs{i, 2};
        stdVar      = responseDefs{i, 3};
        displayName = responseDefs{i, 4};

        y = data.analysisTable.(responseVar);
        if ismember(stdVar, data.analysisTable.Properties.VariableNames)
            yStd = data.analysisTable.(stdVar);
        else
            yStd = nan(size(y));
        end

        fprintf('\n===============================================================\n');
        fprintf(' Fitting surrogate for %s\n', displayName);
        fprintf('===============================================================\n');

        model = select_best_model(data.X, y, yStd, displayName, settings);

        models.(fieldName) = model;

        metricRows = [metricRows; { ...
            displayName, ...
            model.name, ...
            model.fitType, ...
            model.trainMetrics.R2, model.trainMetrics.RMSE, model.trainMetrics.MAE, ...
            model.cvMetrics.R2, model.cvMetrics.RMSE, model.cvMetrics.MAE, ...
            model.isWeakModel}]; %#ok<AGROW>
    end

    modelsForFcn = models;
    models.Rt_fun = @(x) predict_response_model(modelsForFcn.Rt, x);
    models.Rz_fun = @(x) predict_response_model(modelsForFcn.Rz, x);
    models.TW_fun = @(x) predict_response_model(modelsForFcn.ToolWear, x);

    models.metricsTable = cell2table(metricRows, 'VariableNames', { ...
        'Response', 'SelectedModel', 'FitType', ...
        'Train_R2', 'Train_RMSE', 'Train_MAE', ...
        'CV_R2', 'CV_RMSE', 'CV_MAE', ...
        'WeakModelWarning'});

    fprintf('\n--- Selected surrogate model summary ---\n');
    disp(models.metricsTable);
end
