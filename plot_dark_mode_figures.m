
function plot_dark_mode_figures(data, models, psoResults, stability, pareto, sensitivity, settings)
%PLOT_DARK_MODE_FIGURES Create dark-mode-friendly figures for the case study.
%
% Plots generated:
% 1) data summary pairwise plots
% 2) correlation heatmap
% 3) model quality figures for each response
% 4) PSO convergence
% 5) trade-off plots from Pareto-style sampling
% 6) stability plots across repeated PSO runs
% 7) one-factor-at-a-time sensitivity sweeps

    colors = settings.plot.theme.colors;
    ms = settings.plot.markerSize;
    lw = settings.plot.lineWidth;

    %% 1) Pairwise scatter / histogram matrix
    vars = [data.analysisTable.Vc, data.analysisTable.f, data.analysisTable.DOC, ...
            data.analysisTable.Rt_avg, data.analysisTable.Rz_avg, data.analysisTable.ToolWear_avg];

    labels = {'Vc (m/min)', 'f (mm/min)', 'DOC (mm)', 'Rt_{avg} (\mum)', 'Rz_{avg} (\mum)', 'Tool wear (mm)'};
    nVar = numel(labels);

    fig = figure('Name', 'Data pairwise summary', 'Color', settings.plot.theme.bg, ...
        'Position', [80 80 1400 1100]);
    t = tiledlayout(nVar, nVar, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(t, 'Experimental data summary: pairwise plots and distributions', 'Color', settings.plot.theme.fg, 'FontWeight', 'bold');

    for i = 1:nVar
        for j = 1:nVar
            ax = nexttile((i-1)*nVar + j);

            if i == j
                h = histogram(vars(:, j), 'FaceColor', colors(mod(j-1, size(colors,1))+1, :), ...
                    'EdgeColor', settings.plot.theme.fg, 'LineWidth', 0.8);
                h.FaceAlpha = 0.85;
            else
                scatter(vars(:, j), vars(:, i), ms, ...
                    'MarkerFaceColor', colors(mod(i+j-2, size(colors,1))+1, :), ...
                    'MarkerEdgeColor', [0.95 0.95 0.95], ...
                    'MarkerFaceAlpha', 0.85, 'LineWidth', 0.8);
            end

            if i == nVar
                xlabel(labels{j}, 'Color', settings.plot.theme.fg);
            else
                ax.XTickLabel = [];
            end

            if j == 1
                ylabel(labels{i}, 'Color', settings.plot.theme.fg);
            else
                ax.YTickLabel = [];
            end
        end
    end
    apply_dark_theme(fig, settings);
    save_figure_dark(fig, settings, '01_data_pairwise_summary');

    %% 2) Correlation heatmap
    corrMat = corrcoef(vars, 'Rows', 'pairwise');

    fig = figure('Name', 'Correlation heatmap', 'Color', settings.plot.theme.bg, ...
        'Position', [120 120 900 700]);
    imagesc(corrMat);
    axis equal tight;
    colormap(local_colormap());
    c = colorbar;
    c.Label.String = 'Correlation coefficient';
    c.Label.Color = settings.plot.theme.fg;

    xticks(1:nVar);
    yticks(1:nVar);
    xticklabels(labels);
    yticklabels(labels);
    xtickangle(25);
    title('Correlation heatmap of inputs and modeled responses', 'Color', settings.plot.theme.fg, 'FontWeight', 'bold');

    for i = 1:nVar
        for j = 1:nVar
            text(j, i, sprintf('%.2f', corrMat(i, j)), ...
                'HorizontalAlignment', 'center', ...
                'Color', settings.plot.theme.fg, ...
                'FontWeight', 'bold');
        end
    end

    apply_dark_theme(fig, settings);
    save_figure_dark(fig, settings, '02_correlation_heatmap');

    %% 3) Model quality plots
    responseFields = {'Rt', 'Rz', 'ToolWear'};
    responseDisplay = {'Rt_{avg}', 'Rz_{avg}', 'Tool wear'};
    responseUnits = {'\mum', '\mum', 'mm'};

    for k = 1:numel(responseFields)
        mdl = models.(responseFields{k});

        fig = figure('Name', ['Model quality - ' responseFields{k}], 'Color', settings.plot.theme.bg, ...
            'Position', [100 100 1400 450]);
        t = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
        title(t, sprintf('Model quality for %s (%s)', responseDisplay{k}, mdl.name), ...
            'Color', settings.plot.theme.fg, 'FontWeight', 'bold');

        % Actual vs fitted by sample index
        nexttile;
        idx = 1:numel(mdl.y);
        plot(idx, mdl.y, '-o', 'Color', colors(1,:), 'MarkerFaceColor', colors(1,:), 'LineWidth', lw);
        hold on;
        plot(idx, mdl.cvPred, '-s', 'Color', colors(2,:), 'MarkerFaceColor', colors(2,:), 'LineWidth', lw);
        xlabel('Sample index');
        ylabel(sprintf('%s (%s)', responseDisplay{k}, responseUnits{k}));
        title('Actual vs LOOCV prediction');
        legend({'Actual', 'LOOCV pred'}, 'Location', 'best');

        % Parity plot
        nexttile;
        scatter(mdl.y, mdl.cvPred, ms+10, 'filled', ...
            'MarkerFaceColor', colors(3,:), ...
            'MarkerEdgeColor', [0.95 0.95 0.95], 'LineWidth', 0.8);
        hold on;
        minVal = min([mdl.y; mdl.cvPred]);
        maxVal = max([mdl.y; mdl.cvPred]);
        plot([minVal maxVal], [minVal maxVal], '--', 'Color', colors(5,:), 'LineWidth', lw);
        xlabel('Actual');
        ylabel('Predicted');
        title(sprintf('Parity plot | LOOCV R^2 = %+0.3f', mdl.cvMetrics.R2));

        % Residuals
        nexttile;
        residuals = mdl.y - mdl.cvPred;
        scatter(mdl.cvPred, residuals, ms+10, 'filled', ...
            'MarkerFaceColor', colors(4,:), ...
            'MarkerEdgeColor', [0.95 0.95 0.95], 'LineWidth', 0.8);
        hold on;
        yline(0, '--', 'Color', colors(5,:), 'LineWidth', lw);
        xlabel('Predicted');
        ylabel('Residual = actual - predicted');
        title('Residual plot');

        apply_dark_theme(fig, settings);
        save_figure_dark(fig, settings, sprintf('03_model_quality_%s', lower(responseFields{k})));
    end

    %% 4) PSO convergence plots
    history = psoResults.bestHistory;
    iter = (1:numel(history.bestObjective))';

    fig = figure('Name', 'PSO convergence', 'Color', settings.plot.theme.bg, ...
        'Position', [100 100 1200 500]);
    t = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(t, 'PSO convergence for the best run', 'Color', settings.plot.theme.fg, 'FontWeight', 'bold');

    nexttile;
    plot(iter, history.bestObjective, '-', 'Color', colors(1,:), 'LineWidth', lw+0.2);
    hold on;
    plot(iter, history.meanObjective, '--', 'Color', colors(2,:), 'LineWidth', lw);
    xlabel('Iteration');
    ylabel('Objective J');
    title('Objective convergence');
    legend({'Best objective', 'Mean swarm objective'}, 'Location', 'best');

    nexttile;
    plot(iter, history.bestRt, '-', 'Color', colors(3,:), 'LineWidth', lw);
    hold on;
    plot(iter, history.bestRz, '-', 'Color', colors(4,:), 'LineWidth', lw);
    plot(iter, history.bestToolWear, '-', 'Color', colors(5,:), 'LineWidth', lw);
    xlabel('Iteration');
    ylabel('Predicted response value');
    title('Best-so-far predicted responses');
    legend({'Rt_{avg}', 'Rz_{avg}', 'Tool wear'}, 'Location', 'best');

    apply_dark_theme(fig, settings);
    save_figure_dark(fig, settings, '04_pso_convergence');

    %% 5) Trade-off plots
    fig = figure('Name', 'Trade-off plots', 'Color', settings.plot.theme.bg, ...
        'Position', [100 100 1300 520]);
    t = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(t, 'Trade-off exploration among Rz, Rt, and tool wear', 'Color', settings.plot.theme.fg, 'FontWeight', 'bold');

    nexttile;
    scatter3(pareto.all.Rz_pred, pareto.all.Rt_pred, pareto.all.ToolWear_pred, ...
        16, pareto.all.Objective, 'filled');
    hold on;
    plot3(pareto.front.Rz_pred, pareto.front.Rt_pred, pareto.front.ToolWear_pred, ...
        'o', 'LineStyle', 'none', 'MarkerSize', 5.5, 'Color', colors(5,:), 'LineWidth', 1.0);
    scatter3(psoResults.bestPred.Rz, psoResults.bestPred.Rt, psoResults.bestPred.ToolWear, ...
        130, 'p', 'filled', 'MarkerFaceColor', colors(2,:), 'MarkerEdgeColor', [1 1 1]);
    xlabel('Rz_{avg} (\mum)');
    ylabel('Rt_{avg} (\mum)');
    zlabel('Tool wear (mm)');
    title('3D trade-off cloud');
    legend({'Sampled candidates', 'Non-dominated set', 'Best weighted solution'}, 'Location', 'best');
    view(35, 22);
    cb = colorbar;
    cb.Label.String = 'Objective J';

    nexttile;
    bubbleSize = 24 + 450*local_rescale(pareto.all.ToolWear_pred);
    scatter(pareto.all.Rz_pred, pareto.all.Rt_pred, bubbleSize, ...
        pareto.all.ToolWear_pred, 'filled');
    hold on;
    scatter(psoResults.bestPred.Rz, psoResults.bestPred.Rt, 160, 'p', 'filled', ...
        'MarkerFaceColor', colors(2,:), 'MarkerEdgeColor', [1 1 1]);
    xlabel('Rz_{avg} (\mum)');
    ylabel('Rt_{avg} (\mum)');
    title('Bubble view: bubble size/color = tool wear');
    cb = colorbar;
    cb.Label.String = 'Tool wear (mm)';

    apply_dark_theme(fig, settings);
    save_figure_dark(fig, settings, '05_tradeoff_plots');

    %% 6) Stability plots across repeated PSO runs
    rt = stability.runTable;

    fig = figure('Name', 'PSO stability', 'Color', settings.plot.theme.bg, ...
        'Position', [100 100 1200 800]);
    t = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(t, 'Stability of repeated PSO runs', 'Color', settings.plot.theme.fg, 'FontWeight', 'bold');

    nexttile;
    histogram(rt.BestObjective, 'FaceColor', colors(1,:), 'EdgeColor', settings.plot.theme.fg, 'LineWidth', 0.9);
    xlabel('Best objective J');
    ylabel('Count');
    title('Distribution of best objective');

    nexttile;
    histogram(rt.Vc, 'FaceColor', colors(2,:), 'EdgeColor', settings.plot.theme.fg, 'LineWidth', 0.9);
    xlabel('Vc (m/min)');
    ylabel('Count');
    title('Distribution of best Vc');

    nexttile;
    histogram(rt.f, 'FaceColor', colors(3,:), 'EdgeColor', settings.plot.theme.fg, 'LineWidth', 0.9);
    xlabel('f (mm/min)');
    ylabel('Count');
    title('Distribution of best f');

    nexttile;
    histogram(rt.DOC, 'FaceColor', colors(4,:), 'EdgeColor', settings.plot.theme.fg, 'LineWidth', 0.9);
    xlabel('DOC (mm)');
    ylabel('Count');
    title('Distribution of best DOC');

    apply_dark_theme(fig, settings);
    save_figure_dark(fig, settings, '06_pso_stability');

    %% 7) Sensitivity sweeps around the optimum
    fig = figure('Name', 'Sensitivity sweeps', 'Color', settings.plot.theme.bg, ...
        'Position', [80 80 1400 900]);
    t = tiledlayout(3, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(t, 'One-factor-at-a-time sensitivity sweeps around the PSO optimum', ...
        'Color', settings.plot.theme.fg, 'FontWeight', 'bold');

    for v = 1:3
        sw = sensitivity.sweeps(v);

        nexttile;
        plot(sw.x, sw.Rt, '-', 'Color', colors(1,:), 'LineWidth', lw);
        xlabel(sprintf('%s (%s)', sw.varName, data.inputUnits{v}));
        ylabel('Rt_{avg} (\mum)');
        title(sprintf('Rt vs %s', sw.varName));

        nexttile;
        plot(sw.x, sw.Rz, '-', 'Color', colors(2,:), 'LineWidth', lw);
        xlabel(sprintf('%s (%s)', sw.varName, data.inputUnits{v}));
        ylabel('Rz_{avg} (\mum)');
        title(sprintf('Rz vs %s', sw.varName));

        nexttile;
        plot(sw.x, sw.ToolWear, '-', 'Color', colors(3,:), 'LineWidth', lw);
        xlabel(sprintf('%s (%s)', sw.varName, data.inputUnits{v}));
        ylabel('Tool wear (mm)');
        title(sprintf('Tool wear vs %s', sw.varName));
    end

    apply_dark_theme(fig, settings);
    save_figure_dark(fig, settings, '07_sensitivity_sweeps');
end


function y = local_rescale(x)
    xmin = min(x);
    xmax = max(x);
    y = (x - xmin) ./ max(xmax - xmin, eps);
end


function cm = local_colormap()
    try
        cm = turbo(256);
    catch
        cm = parula(256);
    end
end
