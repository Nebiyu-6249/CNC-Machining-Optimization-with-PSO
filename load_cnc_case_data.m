
function raw = load_cnc_case_data(excelFile, sheetName)
%LOAD_CNC_CASE_DATA Read the workbook using readcell so mixed header rows,
%text cells, and numeric cells can all be handled robustly.
%
% Inputs:
%   excelFile - path to workbook
%   sheetName - sheet to read (expected: Sheet1)
%
% Output:
%   raw - struct containing raw cell content and metadata

    if nargin < 2 || isempty(sheetName)
        sheetName = 'Sheet1';
    end

    if ~isfile(excelFile)
        error('Workbook not found: %s', excelFile);
    end

    fprintf('\n--- Loading workbook ---\n');
    fprintf('File  : %s\n', excelFile);
    fprintf('Sheet : %s\n', sheetName);

    try
        cells = readcell(excelFile, 'Sheet', sheetName, 'UseExcel', false);
    catch ME
        warning('readcell with UseExcel=false failed. Retrying with default reader.');
        cells = readcell(excelFile, 'Sheet', sheetName);
        warning('Fallback reader used because: %s', ME.message);
    end

    raw = struct();
    raw.sourceFile = excelFile;
    raw.sheetName = sheetName;
    raw.cells = cells;
    raw.nRows = size(cells, 1);
    raw.nCols = size(cells, 2);

    fprintf('Workbook loaded: %d rows x %d columns\n', raw.nRows, raw.nCols);
end
