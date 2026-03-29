
function save_figure_dark(fig, settings, baseName)
%SAVE_FIGURE_DARK Save a figure as PNG and optionally FIG.

    if ~settings.plot.saveFigures
        return;
    end

    pngFile = fullfile(settings.figureDir, [baseName, '.png']);

    try
        exportgraphics(fig, pngFile, 'Resolution', 300);
    catch
        saveas(fig, pngFile);
    end

    if isfield(settings.plot, 'saveFigFiles') && settings.plot.saveFigFiles
        try
            savefig(fig, fullfile(settings.figureDir, [baseName, '.fig']));
        catch
            % Ignore if savefig is not available
        end
    end
end
