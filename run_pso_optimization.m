
function psoResults = run_pso_optimization(models, data, settings)
%RUN_PSO_OPTIMIZATION Run custom PSO multiple times with different seeds.
%
% Why custom PSO here?
% - no dependence on the Global Optimization Toolbox
% - easier for students to inspect and understand
% - direct control of convergence logging and stability analysis

    seeds = settings.pso.seeds(:);
    nRuns = numel(seeds);

    allRuns = repmat(struct(), nRuns, 1);

    fprintf('\n===============================================================\n');
    fprintf(' Running PSO optimization (%d repeated runs)\n', nRuns);
    fprintf('===============================================================\n');

    for r = 1:nRuns
        seed = seeds(r);
        fprintf('\n--- PSO run %d / %d | seed = %d ---\n', r, nRuns, seed);
        rng(seed, 'twister');
        allRuns(r) = single_pso_run(models, settings, seed);
        fprintf('Best objective: %.6f\n', allRuns(r).bestObjective);
        fprintf('Best x         : [%.6f, %.6f, %.6f]\n', allRuns(r).bestX(1), allRuns(r).bestX(2), allRuns(r).bestX(3));
    end

    allObjectives = arrayfun(@(s) s.bestObjective, allRuns);
    [~, bestIdx] = min(allObjectives);

    psoResults = struct();
    psoResults.allRuns = allRuns;
    psoResults.bestRunIndex = bestIdx;
    psoResults.bestRun = allRuns(bestIdx);
    psoResults.bestObjective = allRuns(bestIdx).bestObjective;
    psoResults.bestX = allRuns(bestIdx).bestX;
    psoResults.bestPred = allRuns(bestIdx).bestPred;
    psoResults.bestHistory = allRuns(bestIdx).history;
    psoResults.settings = settings.pso;

    psoResults.runTable = table( ...
        seeds, ...
        reshape(arrayfun(@(s) s.bestX(1), allRuns), [], 1), ...
        reshape(arrayfun(@(s) s.bestX(2), allRuns), [], 1), ...
        reshape(arrayfun(@(s) s.bestX(3), allRuns), [], 1), ...
        reshape(arrayfun(@(s) s.bestPred.Rt, allRuns), [], 1), ...
        reshape(arrayfun(@(s) s.bestPred.Rz, allRuns), [], 1), ...
        reshape(arrayfun(@(s) s.bestPred.ToolWear, allRuns), [], 1), ...
        reshape(arrayfun(@(s) s.bestObjective, allRuns), [], 1), ...
        'VariableNames', {'Seed', 'Vc', 'f', 'DOC', 'Rt_pred', 'Rz_pred', 'ToolWear_pred', 'BestObjective'});

    writetable(psoResults.runTable, fullfile(settings.tableDir, 'pso_run_summary.csv'));
end

function runResult = single_pso_run(models, settings, seed)
    lb = settings.bounds.lb(:)';
    ub = settings.bounds.ub(:)';
    nVar = numel(lb);

    nPop = settings.pso.swarmSize;
    maxIter = settings.pso.maxIter;
    c1 = settings.pso.c1;
    c2 = settings.pso.c2;
    wStart = settings.pso.wStart;
    wEnd = settings.pso.wEnd;
    vMax = settings.pso.vMaxFraction * (ub - lb);

    % Particle initialization
    pos = repmat(lb, nPop, 1) + rand(nPop, nVar) .* repmat((ub - lb), nPop, 1);
    vel = zeros(nPop, nVar);

    pBestPos = pos;
    pBestObj = inf(nPop, 1);
    pBestPred = repmat(struct('Rt', NaN, 'Rz', NaN, 'ToolWear', NaN), nPop, 1);

    gBestPos = pos(1, :);
    gBestObj = inf;
    gBestPred = struct('Rt', NaN, 'Rz', NaN, 'ToolWear', NaN);

    history.bestObjective = nan(maxIter, 1);
    history.meanObjective = nan(maxIter, 1);
    history.bestX = nan(maxIter, nVar);
    history.bestRt = nan(maxIter, 1);
    history.bestRz = nan(maxIter, 1);
    history.bestToolWear = nan(maxIter, 1);

    stallCounter = 0;
    bestObjLastCheck = inf;

    for iter = 1:maxIter
        w = wStart - (wStart - wEnd) * (iter - 1) / max(maxIter - 1, 1);
        currentObj = nan(nPop, 1);

        % Evaluate swarm
        for i = 1:nPop
            [objVal, detail] = objective_function(pos(i, :), models, settings);
            currentObj(i) = objVal;

            if objVal < pBestObj(i)
                pBestObj(i) = objVal;
                pBestPos(i, :) = pos(i, :);
                pBestPred(i) = struct('Rt', detail.Rt, 'Rz', detail.Rz, 'ToolWear', detail.ToolWear);
            end

            if objVal < gBestObj
                gBestObj = objVal;
                gBestPos = pos(i, :);
                gBestPred = struct('Rt', detail.Rt, 'Rz', detail.Rz, 'ToolWear', detail.ToolWear);
            end
        end

        % Log current best
        history.bestObjective(iter) = gBestObj;
        history.meanObjective(iter) = mean(currentObj, 'omitnan');
        history.bestX(iter, :) = gBestPos;
        history.bestRt(iter) = gBestPred.Rt;
        history.bestRz(iter) = gBestPred.Rz;
        history.bestToolWear(iter) = gBestPred.ToolWear;

        % Stopping logic based on lack of improvement
        if abs(gBestObj - bestObjLastCheck) < settings.pso.tol
            stallCounter = stallCounter + 1;
        else
            stallCounter = 0;
        end
        bestObjLastCheck = gBestObj;

        if stallCounter >= settings.pso.stallIter
            history.bestObjective = history.bestObjective(1:iter);
            history.meanObjective = history.meanObjective(1:iter);
            history.bestX = history.bestX(1:iter, :);
            history.bestRt = history.bestRt(1:iter);
            history.bestRz = history.bestRz(1:iter);
            history.bestToolWear = history.bestToolWear(1:iter);
            fprintf('Stopping early at iteration %d due to stall.\n', iter);
            break;
        end

        % Velocity and position update
        for i = 1:nPop
            r1 = rand(1, nVar);
            r2 = rand(1, nVar);

            vel(i, :) = w * vel(i, :) ...
                      + c1 * r1 .* (pBestPos(i, :) - pos(i, :)) ...
                      + c2 * r2 .* (gBestPos - pos(i, :));

            % Velocity clamping
            vel(i, :) = min(max(vel(i, :), -vMax), vMax);

            pos(i, :) = pos(i, :) + vel(i, :);

            % Bound handling: reflect and clamp
            lowMask = pos(i, :) < lb;
            highMask = pos(i, :) > ub;

            vel(i, lowMask | highMask) = -0.5 * vel(i, lowMask | highMask);
            pos(i, :) = min(max(pos(i, :), lb), ub);
        end
    end

    runResult = struct();
    runResult.seed = seed;
    runResult.bestX = gBestPos;
    runResult.bestObjective = gBestObj;
    runResult.bestPred = gBestPred;
    runResult.history = history;
end
