
function plot_response_surfaces(models, psoResults, settings)
%PLOT_RESPONSE_SURFACES Create 3D surface and contour plots for:
% - Vc vs f at fixed DOC
% - Vc vs DOC at fixed f
% - f vs DOC at fixed Vc
%
% The held variable is fixed at the best PSO solution.

    bestX = psoResults.bestX(:)';
    lb = settings.bounds.lb(:)';
    ub = settings.bounds.ub(:)';
    names = settings.bounds.names;
    units = settings.bounds.units;
    nGrid = settings.plot.surfaceGridN;

    pairList = [1 2; 1 3; 2 3];
    responseDefs = { ...
        'Rt',       'Rt_{avg}',       '\mum'; ...
        'Rz',       'Rz_{avg}',       '\mum'; ...
        'ToolWear', 'Tool wear',      'mm'};

    for r = 1:size(responseDefs, 1)
        mdl = models.(responseDefs{r,1});
        responseLabel = responseDefs{r,2};
        responseUnit = responseDefs{r,3};

        fig = figure('Name', ['Response surfaces - ' responseDefs{r,1}], ...
            'Color', settings.plot.theme.bg, ...
            'Position', [70 70 1450 1050]);
        t = tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
        title(t, sprintf('%s response surfaces (held variable fixed at PSO optimum)', responseLabel), ...
            'Color', settings.plot.theme.fg, 'FontWeight', 'bold');

        for p = 1:size(pairList, 1)
            i = pairList(p,1);
            j = pairList(p,2);
            kHold = setdiff(1:3, [i j]);

            xi = linspace(lb(i), ub(i), nGrid);
            xj = linspace(lb(j), ub(j), nGrid);
            [XI, XJ] = meshgrid(xi, xj);

            Xeval = repmat(bestX, numel(XI), 1);
            Xeval(:, i) = XI(:);
            Xeval(:, j) = XJ(:);
            Xeval(:, kHold) = bestX(kHold);

            Z = predict_response_model(mdl, Xeval);
            Z = reshape(Z, size(XI));

            % Surface
            nexttile;
            surf(XI, XJ, Z, 'EdgeColor', 'none', 'FaceAlpha', 0.96);
            hold on;
            zBest = predict_response_model(mdl, bestX);
            plot3(bestX(i), bestX(j), zBest, 'p', 'MarkerSize', 12, ...
                'MarkerFaceColor', settings.plot.theme.colors(2,:), ...
                'MarkerEdgeColor', [1 1 1], 'LineWidth', 1.2);
            xlabel(sprintf('%s (%s)', names{i}, units{i}));
            ylabel(sprintf('%s (%s)', names{j}, units{j}));
            zlabel(sprintf('%s (%s)', responseLabel, responseUnit));
            title(sprintf('%s vs %s | %s = %.4f', names{i}, names{j}, names{kHold}, bestX(kHold)));
            view(35, 25);
            colormap(local_colormap());
            cb = colorbar;
            cb.Label.String = sprintf('%s (%s)', responseLabel, responseUnit);

            % Contour
            nexttile;
            contourf(XI, XJ, Z, 18, 'LineColor', 'none');
            hold on;
            plot(bestX(i), bestX(j), 'p', 'MarkerSize', 12, ...
                'MarkerFaceColor', settings.plot.theme.colors(2,:), ...
                'MarkerEdgeColor', [1 1 1], 'LineWidth', 1.2);
            xlabel(sprintf('%s (%s)', names{i}, units{i}));
            ylabel(sprintf('%s (%s)', names{j}, units{j}));
            title(sprintf('Contour: %s vs %s', names{i}, names{j}));
            colormap(local_colormap());
            cb = colorbar;
            cb.Label.String = sprintf('%s (%s)', responseLabel, responseUnit);
        end

        apply_dark_theme(fig, settings);
        save_figure_dark(fig, settings, sprintf('08_response_surface_%s', lower(responseDefs{r,1})));
    end
end


function cm = local_colormap()
    try
        cm = turbo(256);
    catch
        cm = parula(256);
    end
end
