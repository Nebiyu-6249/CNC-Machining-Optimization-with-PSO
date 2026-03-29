
function apply_dark_theme(fig, settings)
%APPLY_DARK_THEME Apply a dark visual style to the current figure.

    if nargin < 1 || isempty(fig)
        fig = gcf;
    end

    theme = settings.plot.theme;

    set(fig, 'Color', theme.bg);

    axList = findall(fig, 'Type', 'axes');
    for k = 1:numel(axList)
        ax = axList(k);

        set(ax, ...
            'Color', theme.ax, ...
            'XColor', theme.fg, ...
            'YColor', theme.fg, ...
            'ZColor', theme.fg, ...
            'GridColor', theme.grid, ...
            'MinorGridColor', theme.grid, ...
            'LineWidth', 1.0, ...
            'FontName', 'Arial', ...
            'FontSize', 10);

        grid(ax, 'on');
        box(ax, 'on');

        if isprop(ax, 'Title') && ~isempty(ax.Title)
            ax.Title.Color = theme.fg;
        end
        if isprop(ax, 'XLabel') && ~isempty(ax.XLabel)
            ax.XLabel.Color = theme.fg;
        end
        if isprop(ax, 'YLabel') && ~isempty(ax.YLabel)
            ax.YLabel.Color = theme.fg;
        end
        if isprop(ax, 'ZLabel') && ~isempty(ax.ZLabel)
            ax.ZLabel.Color = theme.fg;
        end
    end

    lgList = findall(fig, 'Type', 'legend');
    for k = 1:numel(lgList)
        lg = lgList(k);
        lg.TextColor = theme.fg;
        lg.Color = theme.ax;
        lg.EdgeColor = theme.grid;
    end

    cbList = findall(fig, 'Type', 'ColorBar');
    for k = 1:numel(cbList)
        cb = cbList(k);
        cb.Color = theme.fg;
    end
end
