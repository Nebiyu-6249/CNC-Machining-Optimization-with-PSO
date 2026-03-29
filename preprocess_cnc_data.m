
function data = preprocess_cnc_data(raw, settings)
%PREPROCESS_CNC_DATA Build the final clean analysis dataset from the mixed
%Excel layout.
%
% Required columns in the workbook:
% - Inputs:
%   B = Vc
%   C = f
%   D = DOC
% - Tool wear:
%   E:H = raw flank wear measurements
%   I   = average/check column
% - Surface roughness:
%   L,R,X = Rt replicate values
%   M,S,Y = Rz replicate values
%
% The function:
% - identifies data rows programmatically
% - converts text numerics safely
% - handles decimal commas
% - builds clean response averages and standard deviations
% - flags invalid rows
% - prints a concise summary suitable for a case study

    C = raw.cells;
    nRows = size(C, 1);

    % Identify likely data rows:
    % we require B,C,D to be numeric after safe conversion.
    dataRows = [];
    for r = 1:nRows
        Vc  = safe_numeric(cell_or_empty(C, r, 2));
        f   = safe_numeric(cell_or_empty(C, r, 3));
        DOC = safe_numeric(cell_or_empty(C, r, 4));

        if all(isfinite([Vc, f, DOC]))
            dataRows(end+1,1) = r; %#ok<AGROW>
        end
    end

    if isempty(dataRows)
        error('No usable data rows were found. Check workbook structure.');
    end

    n = numel(dataRows);

    RunID = nan(n,1);
    Vc = nan(n,1);
    f = nan(n,1);
    DOC = nan(n,1);

    ToolWear_avg = nan(n,1);
    ToolWear_std = nan(n,1);
    ToolWear_check = nan(n,1);
    ToolWear_checkDiff = nan(n,1);

    Rt_avg = nan(n,1);
    Rt_std = nan(n,1);

    Rz_avg = nan(n,1);
    Rz_std = nan(n,1);

    nWearValid = zeros(n,1);
    nRtValid = zeros(n,1);
    nRzValid = zeros(n,1);
    sourceRow = zeros(n,1);
    isValid = false(n,1);
    issueNote = repmat({''}, n, 1);

    for i = 1:n
        r = dataRows(i);
        sourceRow(i) = r;

        RunID(i) = safe_numeric(cell_or_empty(C, r, 1));
        Vc(i)    = safe_numeric(cell_or_empty(C, r, 2));
        f(i)     = safe_numeric(cell_or_empty(C, r, 3));
        DOC(i)   = safe_numeric(cell_or_empty(C, r, 4));

        wearRaw = [
            safe_numeric(cell_or_empty(C, r, 5)), ...
            safe_numeric(cell_or_empty(C, r, 6)), ...
            safe_numeric(cell_or_empty(C, r, 7)), ...
            safe_numeric(cell_or_empty(C, r, 8))
        ];

        wearCheck = safe_numeric(cell_or_empty(C, r, 9));

        RtRaw = [
            safe_numeric(cell_or_empty(C, r, 12)), ...
            safe_numeric(cell_or_empty(C, r, 18)), ...
            safe_numeric(cell_or_empty(C, r, 24))
        ];

        RzRaw = [
            safe_numeric(cell_or_empty(C, r, 13)), ...
            safe_numeric(cell_or_empty(C, r, 19)), ...
            safe_numeric(cell_or_empty(C, r, 25))
        ];

        nWearValid(i) = sum(isfinite(wearRaw));
        nRtValid(i)   = sum(isfinite(RtRaw));
        nRzValid(i)   = sum(isfinite(RzRaw));

        ToolWear_avg(i) = mean(wearRaw, 'omitnan');
        ToolWear_std(i) = std(wearRaw, 0, 'omitnan');
        ToolWear_check(i) = wearCheck;

        if isfinite(wearCheck) && isfinite(ToolWear_avg(i))
            ToolWear_checkDiff(i) = abs(ToolWear_avg(i) - wearCheck);
        end

        Rt_avg(i) = mean(RtRaw, 'omitnan');
        Rt_std(i) = std(RtRaw, 0, 'omitnan');

        Rz_avg(i) = mean(RzRaw, 'omitnan');
        Rz_std(i) = std(RzRaw, 0, 'omitnan');

        % Valid row rule:
        % inputs must be finite and each main response must have at least two
        % valid replicate values.
        thisValid = all(isfinite([Vc(i), f(i), DOC(i)])) && ...
                    (nWearValid(i) >= 2) && ...
                    (nRtValid(i) >= 2) && ...
                    (nRzValid(i) >= 2);

        isValid(i) = thisValid;

        if ~thisValid
            issueNote{i} = 'Insufficient valid data in one or more response groups';
        elseif ~isnan(ToolWear_checkDiff(i)) && ToolWear_checkDiff(i) > 1e-6
            issueNote{i} = 'Tool wear check column differs slightly from mean(E:H)';
        else
            issueNote{i} = 'OK';
        end
    end

    analysisTable = table( ...
        RunID, sourceRow, Vc, f, DOC, ...
        ToolWear_avg, ToolWear_std, ToolWear_check, ToolWear_checkDiff, ...
        Rt_avg, Rt_std, ...
        Rz_avg, Rz_std, ...
        nWearValid, nRtValid, nRzValid, isValid, issueNote, ...
        'VariableNames', { ...
        'RunID', 'SourceRow', 'Vc', 'f', 'DOC', ...
        'ToolWear_avg', 'ToolWear_std', 'ToolWear_check', 'ToolWear_checkDiff', ...
        'Rt_avg', 'Rt_std', ...
        'Rz_avg', 'Rz_std', ...
        'nWearValid', 'nRtValid', 'nRzValid', 'isValid', 'IssueNote'});

    % Keep only valid rows in the final modeling dataset.
    invalidCount = sum(~analysisTable.isValid);
    if invalidCount > 0
        warning('%d row(s) were flagged invalid and removed from modeling.', invalidCount);
    end

    analysisTable = analysisTable(analysisTable.isValid, :);

    if isempty(analysisTable)
        error('All rows were removed during preprocessing. No dataset remains.');
    end

    % Detect unique design points and repeated center point.
    X = [analysisTable.Vc, analysisTable.f, analysisTable.DOC];
    [uniqueX, ~, groupID] = unique(X, 'rows', 'stable');
    counts = accumarray(groupID, 1);
    centerPoint = (settings.bounds.lb + settings.bounds.ub) ./ 2;

    isCenter = abs(analysisTable.Vc - centerPoint(1)) < 1e-12 & ...
               abs(analysisTable.f  - centerPoint(2)) < 1e-12 & ...
               abs(analysisTable.DOC - centerPoint(3)) < 1e-12;

    uniqueTable = array2table(uniqueX, 'VariableNames', {'Vc', 'f', 'DOC'});
    uniqueTable.Count = counts;

    finalVarsTable = analysisTable(:, {'Vc', 'f', 'DOC', 'Rt_avg', 'Rz_avg', 'ToolWear_avg'});

    % Normalization references for the weighted objective.
    responseRef = struct();
    responseRef.Rt.min = min(analysisTable.Rt_avg);
    responseRef.Rt.max = max(analysisTable.Rt_avg);
    responseRef.Rz.min = min(analysisTable.Rz_avg);
    responseRef.Rz.max = max(analysisTable.Rz_avg);
    responseRef.ToolWear.min = min(analysisTable.ToolWear_avg);
    responseRef.ToolWear.max = max(analysisTable.ToolWear_avg);

    % Package data
    data = struct();
    data.analysisTable = analysisTable;
    data.finalVarsTable = finalVarsTable;
    data.uniqueDesignTable = uniqueTable;
    data.responseRef = responseRef;
    data.centerPoint = centerPoint;
    data.centerPointCount = sum(isCenter);
    data.numUniqueDesignPoints = size(uniqueX, 1);
    data.numRows = height(analysisTable);
    data.X = X;
    data.responseNames = {'Rt_avg', 'Rz_avg', 'ToolWear_avg'};
    data.responseUnits = {'um', 'um', 'mm'};
    data.inputNames = settings.bounds.names;
    data.inputUnits = settings.bounds.units;

    % Console summary
    fprintf('\n--- Final extracted dataset summary ---\n');
    fprintf('Valid experimental rows used in modeling : %d\n', height(analysisTable));
    fprintf('Unique design points                     : %d\n', data.numUniqueDesignPoints);
    fprintf('Repeated center points detected          : %d\n', data.centerPointCount);
    fprintf('Detected center point                    : [%.6f, %.6f, %.6f]\n', centerPoint(1), centerPoint(2), centerPoint(3));

    fprintf('\nFinal variables used in modeling:\n');
    disp(finalVarsTable);

    fprintf('Average repeatability indicators (sample std across replicates):\n');
    fprintf('  mean(Rt_std)        = %.6f um\n', mean(analysisTable.Rt_std, 'omitnan'));
    fprintf('  mean(Rz_std)        = %.6f um\n', mean(analysisTable.Rz_std, 'omitnan'));
    fprintf('  mean(ToolWear_std)  = %.6f mm\n', mean(analysisTable.ToolWear_std, 'omitnan'));

    if any(isfinite(analysisTable.ToolWear_checkDiff))
        fprintf('  max |mean(E:H) - col I| = %.6e\n', max(analysisTable.ToolWear_checkDiff, [], 'omitnan'));
    end
end

%% Local helpers
function value = cell_or_empty(C, r, c)
    if r <= size(C, 1) && c <= size(C, 2)
        value = C{r, c};
    else
        value = [];
    end
end

function x = safe_numeric(value)
%SAFE_NUMERIC Convert workbook cell content to numeric robustly.
% Handles:
% - numeric values
% - char / string numerics
% - decimal commas
% - stray text around numbers

    if isempty(value)
        x = NaN;
        return;
    end

    if isnumeric(value)
        if isscalar(value)
            x = double(value);
        else
            x = NaN;
        end
        return;
    end

    if islogical(value)
        x = double(value);
        return;
    end

    if isstring(value)
        value = char(value);
    end

    if ischar(value)
        s = strtrim(value);

        if isempty(s)
            x = NaN;
            return;
        end

        % Replace decimal comma with decimal point
        s = strrep(s, ',', '.');

        % Keep only characters that matter for a numeric parse
        s = regexprep(s, '[^\d\.\-\+eE]', '');

        if isempty(s)
            x = NaN;
            return;
        end

        x = str2double(s);
        if isnan(x)
            x = NaN;
        end
        return;
    end

    x = NaN;
end
