
function model = select_best_model(X, y, yStd, responseName, settings)
%SELECT_BEST_MODEL Evaluate practical surrogate candidates and choose the
%most suitable one for the small CNC dataset.
%
% Candidate order:
% 1) Full quadratic response surface
% 2) Reduced interaction model
% 3) Pure quadratic model
% 4) Linear model
% 5) Weighted practical models (use replicate std if available)
% 6) Ridge-regularized full quadratic
% 7) Optional Gaussian process regression if fitrgp exists and simpler
%    models are poor.
%
% The selection prioritizes:
% - practical interpretability
% - leave-one-out cross-validation
% - avoiding severe overfitting
% - clear warnings when data quality is weak

    n = size(X, 1);

    if numel(y) ~= n
        error('X and y must have the same number of rows.');
    end

    y = y(:);
    if nargin < 3 || isempty(yStd)
        yStd = nan(size(y));
    else
        yStd = yStd(:);
    end

    candidateList = {};

    % OLS polynomial models
    candidateList{end+1} = struct('name', 'FullQuadratic',       'basis', 'fullquadratic', 'fitType', 'ols',   'useWeights', false); %#ok<AGROW>
    candidateList{end+1} = struct('name', 'ReducedInteraction',  'basis', 'interaction',   'fitType', 'ols',   'useWeights', false); %#ok<AGROW>
    candidateList{end+1} = struct('name', 'PureQuadratic',       'basis', 'purequadratic', 'fitType', 'ols',   'useWeights', false); %#ok<AGROW>
    candidateList{end+1} = struct('name', 'Linear',              'basis', 'linear',        'fitType', 'ols',   'useWeights', false); %#ok<AGROW>

    % Weighted models only make sense when repeatability data exists.
    hasRepeatability = any(isfinite(yStd));

    if hasRepeatability
        candidateList{end+1} = struct('name', 'WeightedInteraction',   'basis', 'interaction',   'fitType', 'wls',   'useWeights', true); %#ok<AGROW>
        candidateList{end+1} = struct('name', 'WeightedPureQuadratic', 'basis', 'purequadratic', 'fitType', 'wls',   'useWeights', true); %#ok<AGROW>
        candidateList{end+1} = struct('name', 'WeightedFullQuadratic', 'basis', 'fullquadratic', 'fitType', 'wls',   'useWeights', true); %#ok<AGROW>
    end

    % Ridge full quadratic
    candidateList{end+1} = struct('name', 'RidgeFullQuadratic', 'basis', 'fullquadratic', 'fitType', 'ridge', 'useWeights', false); %#ok<AGROW>

    % Prepare repeatability weights if possible.
    if hasRepeatability
        weights = build_repeatability_weights(yStd);
    else
        weights = ones(size(y));
    end

    results = repmat(struct(), 0, 1);

    baselinePred = mean(y) * ones(size(y));
    baselineMetrics = compute_metrics(y, baselinePred);

    fprintf('Baseline mean-model RMSE = %.6f\n', baselineMetrics.RMSE);

    % Evaluate polynomial / ridge candidates
    for k = 1:numel(candidateList)
        cand = candidateList{k};

        [Phi, termNames, codedX] = build_design_matrix(X, cand.basis, settings.bounds);

        result = struct();
        result.name = cand.name;
        result.basis = cand.basis;
        result.fitType = cand.fitType;
        result.termNames = termNames;
        result.nTerms = size(Phi, 2);
        result.weights = [];
        result.lambda = [];
        result.gprModel = [];
        result.gprBasis = '';
        result.wasFitted = true;
        result.equationString = '';

        if cand.useWeights
            result.weights = weights;
        end

        % Fit on the full dataset
        if strcmpi(cand.fitType, 'ols')
            beta = fit_ols(Phi, y);
        elseif strcmpi(cand.fitType, 'wls')
            beta = fit_wls(Phi, y, weights);
        elseif strcmpi(cand.fitType, 'ridge')
            [beta, lambdaOpt] = fit_ridge_cv(Phi, y, settings.model.ridgeLambdas);
            result.lambda = lambdaOpt;
        else
            error('Unknown fit type: %s', cand.fitType);
        end

        result.beta = beta;
        result.trainPred = Phi * beta;
        result.trainMetrics = compute_metrics(y, result.trainPred);

        % LOOCV prediction
        yCV = nan(n, 1);
        for i = 1:n
            trainMask = true(n, 1);
            trainMask(i) = false;

            PhiTrain = Phi(trainMask, :);
            yTrain = y(trainMask);

            if strcmpi(cand.fitType, 'ols')
                beta_i = fit_ols(PhiTrain, yTrain);
            elseif strcmpi(cand.fitType, 'wls')
                beta_i = fit_wls(PhiTrain, yTrain, weights(trainMask));
            elseif strcmpi(cand.fitType, 'ridge')
                [beta_i, ~] = fit_ridge_cv(PhiTrain, yTrain, settings.model.ridgeLambdas);
            end

            yCV(i) = Phi(i, :) * beta_i;
        end

        result.cvPred = yCV;
        result.cvMetrics = compute_metrics(y, yCV);

        % Rejection / warning logic
        overfitGap = result.trainMetrics.R2 - result.cvMetrics.R2;
        result.overfitGap = overfitGap;
        result.isHardRejected = (result.cvMetrics.R2 < settings.model.rejectR2Hard) || ...
                                (result.trainMetrics.R2 > 0.80 && result.cvMetrics.R2 < 0);
        result.isWeak = result.cvMetrics.R2 < settings.model.warnR2;
        result.selectionScore = result.cvMetrics.R2 ...
                                - 0.02 * (result.nTerms / max(n, 1)) ...
                                - 0.03 * max(overfitGap, 0);

        results(end+1,1) = result; %#ok<AGROW>

        fprintf('\nCandidate: %-22s | fit=%-5s | terms=%2d\n', ...
            result.name, result.fitType, result.nTerms);
        fprintf('  Train: R2 = %+8.4f | RMSE = %.6f | MAE = %.6f\n', ...
            result.trainMetrics.R2, result.trainMetrics.RMSE, result.trainMetrics.MAE);
        fprintf('  LOOCV: R2 = %+8.4f | RMSE = %.6f | MAE = %.6f\n', ...
            result.cvMetrics.R2, result.cvMetrics.RMSE, result.cvMetrics.MAE);

        if result.isHardRejected
            fprintf('  Status: rejected (clear overfitting or very poor cross-validation)\n');
        elseif result.isWeak
            fprintf('  Status: weak model warning (cross-validation quality is limited)\n');
        else
            fprintf('  Status: acceptable practical model\n');
        end
    end

    % Optional GPR candidate only if practical models are weak and fitrgp is available.
    allowGPR = settings.model.tryGPR && exist('fitrgp', 'file') == 2;
    bestSoFarCV = max(arrayfun(@(s) s.cvMetrics.R2, results));

    if allowGPR && bestSoFarCV < settings.model.warnR2
        fprintf('\nAll practical polynomial models are weak for %s.\n', responseName);
        fprintf('Trying optional Gaussian Process Regression (fitrgp).\n');

        gprResult = try_gpr_candidate(X, y);
        if gprResult.wasFitted
            results(end+1,1) = gprResult; %#ok<AGROW>

            fprintf('\nCandidate: %-22s | fit=%-5s\n', gprResult.name, gprResult.fitType);
            fprintf('  Train: R2 = %+8.4f | RMSE = %.6f | MAE = %.6f\n', ...
                gprResult.trainMetrics.R2, gprResult.trainMetrics.RMSE, gprResult.trainMetrics.MAE);
            fprintf('  LOOCV: R2 = %+8.4f | RMSE = %.6f | MAE = %.6f\n', ...
                gprResult.cvMetrics.R2, gprResult.cvMetrics.RMSE, gprResult.cvMetrics.MAE);
        end
    end

    % Select the final model.
    hardRejected = arrayfun(@(s) s.isHardRejected, results);
    acceptableIdx = find(~hardRejected);

    if isempty(acceptableIdx)
        % Last-resort fallback: choose least bad by CV R2, then RMSE
        warning('All models were hard-rejected for %s. Choosing the least-bad model with an explicit warning.', responseName);
        [~, bestIdx] = max(arrayfun(@(s) s.cvMetrics.R2, results));
        chosen = results(bestIdx);
        chosen.reason = 'All candidates were weak. Least-bad model kept only for approximate screening.';
        chosen.isWeak = true;
    else
        acceptable = results(acceptableIdx);

        % Primary key: selectionScore
        % Tie break: higher CV R2, lower CV RMSE, fewer terms
        scores = arrayfun(@(s) s.selectionScore, acceptable);
        bestScore = max(scores);
        tied = acceptable(abs(scores - bestScore) < 1e-12);

        if numel(tied) > 1
            cvR2s = arrayfun(@(s) s.cvMetrics.R2, tied);
            [~, idx2] = max(cvR2s);
            tied2 = tied(abs(cvR2s - cvR2s(idx2)) < 1e-12);

            if numel(tied2) > 1
                rmses = arrayfun(@(s) s.cvMetrics.RMSE, tied2);
                [~, idx3] = min(rmses);
                tied3 = tied2(abs(rmses - rmses(idx3)) < 1e-12);

                if numel(tied3) > 1
                    [~, idx4] = min(arrayfun(@(s) s.nTerms, tied3));
                    chosen = tied3(idx4);
                else
                    chosen = tied2(idx3);
                end
            else
                chosen = tied(idx2);
            end
        else
            chosen = acceptable(scores == bestScore);
            chosen = chosen(1);
        end

        if chosen.cvMetrics.R2 >= settings.model.warnR2
            chosen.reason = sprintf('%s selected because it gave the most practical cross-validated performance.', chosen.name);
        else
            chosen.reason = sprintf('%s selected as the least-overfit practical model, but the response is noisy and the LOOCV R^2 is weak.', chosen.name);
            chosen.isWeak = true;
        end
    end

    % Final packaging
    model = chosen;
    model.responseName = responseName;
    model.bounds = settings.bounds;
    model.codedCenter = (settings.bounds.lb + settings.bounds.ub) ./ 2;
    model.codedHalfRange = (settings.bounds.ub - settings.bounds.lb) ./ 2;
    model.X = X;
    model.y = y;
    model.yStd = yStd;
    model.codedX = codedX_for_basis(X, model, settings.bounds);
    model.baselineMetrics = baselineMetrics;
    model.isWeakModel = model.isWeak;
    model.equationString = build_equation_string(model);

    fprintf('\n--- Selected model for %s ---\n', responseName);
    fprintf('Model name : %s\n', model.name);
    fprintf('Fit type   : %s\n', model.fitType);
    fprintf('Reason     : %s\n', model.reason);
    fprintf('Train R2   : %+8.4f\n', model.trainMetrics.R2);
    fprintf('LOOCV R2   : %+8.4f\n', model.cvMetrics.R2);

    if strcmpi(model.fitType, 'gpr')
        fprintf('Equation   : not a simple explicit polynomial; use predict_response_model / wrapper functions.\n');
    else
        fprintf('Equation   :\n%s\n', model.equationString);
    end

    if model.isWeakModel
        warning(['The selected model for %s is weak in cross-validation. ', ...
                 'Use it carefully and report the uncertainty clearly.'], responseName);
    end
end

%% Helper functions for model fitting
function beta = fit_ols(Phi, y)
    beta = Phi \ y;
end

function beta = fit_wls(Phi, y, w)
    w = w(:);
    Wsqrt = diag(sqrt(w));
    beta = (Wsqrt * Phi) \ (Wsqrt * y);
end

function [beta, lambdaOpt] = fit_ridge_cv(Phi, y, lambdaGrid)
% Fit ridge regression using LOOCV over a supplied lambda grid.
% Intercept term is not penalized.

    n = size(Phi, 1);
    p = size(Phi, 2);

    if isempty(lambdaGrid)
        lambdaGrid = logspace(-4, 4, 40);
    end

    I = eye(p);
    I(1,1) = 0; % do not penalize intercept

    bestPress = inf;
    lambdaOpt = lambdaGrid(1);

    for L = 1:numel(lambdaGrid)
        lambda = lambdaGrid(L);
        press = 0;

        for i = 1:n
            trainMask = true(n,1);
            trainMask(i) = false;

            PhiTrain = Phi(trainMask, :);
            yTrain = y(trainMask);

            beta_i = (PhiTrain' * PhiTrain + lambda * I) \ (PhiTrain' * yTrain);
            err = y(i) - Phi(i, :) * beta_i;
            press = press + err.^2;
        end

        if press < bestPress
            bestPress = press;
            lambdaOpt = lambda;
        end
    end

    beta = (Phi' * Phi + lambdaOpt * I) \ (Phi' * y);
end

function weights = build_repeatability_weights(yStd)
% Use inverse-variance style weights, but cap extremes so one very small
% standard deviation does not dominate the fit too strongly.

    yStd = yStd(:);
    yStd(~isfinite(yStd)) = nan;

    rawWeights = 1 ./ max(yStd.^2, 1e-6);
    validMask = isfinite(rawWeights);

    if any(validMask)
        validWeights = rawWeights(validMask);
        qLow = local_percentile(validWeights, 5);
        qHigh = local_percentile(validWeights, 95);
        rawWeights(validMask) = min(max(validWeights, qLow), qHigh);
        rawWeights(~validMask) = median(validWeights);
    else
        rawWeights = ones(size(yStd));
    end

    weights = rawWeights;
end

function gprResult = try_gpr_candidate(X, y)
% Fit an optional GPR candidate if the toolbox is available.

    n = size(X, 1);

    gprResult = struct();
    gprResult.name = 'GaussianProcessRegression';
    gprResult.basis = 'gpr';
    gprResult.fitType = 'gpr';
    gprResult.termNames = {};
    gprResult.nTerms = size(X, 2);
    gprResult.weights = [];
    gprResult.lambda = [];
    gprResult.gprModel = [];
    gprResult.gprBasis = '';
    gprResult.wasFitted = false;
    gprResult.equationString = '';
    gprResult.beta = [];
    gprResult.trainPred = [];
    gprResult.trainMetrics = struct('R2', NaN, 'RMSE', NaN, 'MAE', NaN);
    gprResult.cvPred = [];
    gprResult.cvMetrics = struct('R2', NaN, 'RMSE', NaN, 'MAE', NaN);
    gprResult.overfitGap = inf;
    gprResult.isHardRejected = false;
    gprResult.isWeak = true;
    gprResult.selectionScore = -inf;

    try
        % Full fit
        mdl = fitrgp(X, y, ...
            'BasisFunction', 'constant', ...
            'KernelFunction', 'ardsquaredexponential', ...
            'Standardize', true);

        trainPred = predict(mdl, X);
        trainMetrics = compute_metrics(y, trainPred);

        % LOOCV
        cvPred = nan(n, 1);
        for i = 1:n
            trainMask = true(n, 1);
            trainMask(i) = false;

            mdl_i = fitrgp(X(trainMask, :), y(trainMask), ...
                'BasisFunction', 'constant', ...
                'KernelFunction', 'ardsquaredexponential', ...
                'Standardize', true);

            cvPred(i) = predict(mdl_i, X(i, :));
        end

        cvMetrics = compute_metrics(y, cvPred);

        gprResult.gprModel = mdl;
        gprResult.trainPred = trainPred;
        gprResult.cvPred = cvPred;
        gprResult.trainMetrics = trainMetrics;
        gprResult.cvMetrics = cvMetrics;
        gprResult.overfitGap = trainMetrics.R2 - cvMetrics.R2;
        gprResult.isHardRejected = (cvMetrics.R2 < -0.25);
        gprResult.isWeak = (cvMetrics.R2 < 0.05);
        gprResult.selectionScore = cvMetrics.R2 - 0.05 * max(gprResult.overfitGap, 0);
        gprResult.wasFitted = true;
        gprResult.equationString = 'No simple closed-form polynomial equation (use prediction function).';
    catch ME
        warning('GPR candidate failed: %s', ME.message);
    end
end

function codedX = codedX_for_basis(X, model, bounds)
% Create coded variables from the physical variables.
    [~, ~, codedX] = build_design_matrix(X, model.basis, bounds);
end

function eqn = build_equation_string(model)
% Return a readable equation string for polynomial-style models.
    if strcmpi(model.fitType, 'gpr')
        eqn = 'No closed-form equation available for the selected GPR model.';
        return;
    end

    beta = model.beta(:);
    terms = model.termNames(:);

    center = model.codedCenter;
    halfRange = model.codedHalfRange;

    header = sprintf(['Use coded variables:\n', ...
        '  x1 = (Vc  - %.6f) / %.6f\n', ...
        '  x2 = (f   - %.6f) / %.6f\n', ...
        '  x3 = (DOC - %.6f) / %.6f\n'], ...
        center(1), halfRange(1), center(2), halfRange(2), center(3), halfRange(3));

    pieces = cell(numel(beta), 1);
    for i = 1:numel(beta)
        if i == 1
            pieces{i} = sprintf('%.6f', beta(i));
        else
            pieces{i} = sprintf('%+ .6f*%s', beta(i), terms{i});
        end
    end

    rhs = strjoin(pieces, ' ');
    eqn = sprintf('%s\n%s = %s', header, model.responseName, rhs);
end


function q = local_percentile(x, p)
%LOCAL_PERCENTILE Simple percentile without requiring Statistics Toolbox.
    x = sort(x(:));
    if isempty(x)
        q = NaN;
        return;
    end
    if numel(x) == 1
        q = x;
        return;
    end
    pos = 1 + (numel(x)-1) * (p/100);
    lo = floor(pos);
    hi = ceil(pos);
    if lo == hi
        q = x(lo);
    else
        q = x(lo) + (pos - lo) * (x(hi) - x(lo));
    end
end
