
function [Phi, termNames, codedX] = build_design_matrix(X, basisName, bounds)
%BUILD_DESIGN_MATRIX Build polynomial design matrices in coded variables.
%
% Inputs:
%   X         - N x 3 matrix with columns [Vc, f, DOC]
%   basisName - model basis string
%   bounds    - settings.bounds struct with lb and ub
%
% Output:
%   Phi       - design matrix
%   termNames - names of terms in Phi
%   codedX    - X mapped to coded variables in [-1, 1]

    if istable(X)
        X = X{:,:};
    end

    X = double(X);

    if size(X, 2) ~= 3
        error('X must be an N x 3 matrix: [Vc, f, DOC].');
    end

    lb = bounds.lb(:)';
    ub = bounds.ub(:)';
    center = (lb + ub) ./ 2;
    halfRange = (ub - lb) ./ 2;

    codedX = (X - center) ./ halfRange;

    x1 = codedX(:, 1);
    x2 = codedX(:, 2);
    x3 = codedX(:, 3);

    switch lower(basisName)
        case 'linear'
            Phi = [ones(size(X,1),1), x1, x2, x3];
            termNames = {'1', 'x1', 'x2', 'x3'};

        case 'interaction'
            Phi = [ones(size(X,1),1), x1, x2, x3, x1.*x2, x1.*x3, x2.*x3];
            termNames = {'1', 'x1', 'x2', 'x3', 'x1x2', 'x1x3', 'x2x3'};

        case 'purequadratic'
            Phi = [ones(size(X,1),1), x1, x2, x3, x1.^2, x2.^2, x3.^2];
            termNames = {'1', 'x1', 'x2', 'x3', 'x1^2', 'x2^2', 'x3^2'};

        case 'fullquadratic'
            Phi = [ones(size(X,1),1), x1, x2, x3, ...
                   x1.*x2, x1.*x3, x2.*x3, ...
                   x1.^2, x2.^2, x3.^2];
            termNames = {'1', 'x1', 'x2', 'x3', 'x1x2', 'x1x3', 'x2x3', 'x1^2', 'x2^2', 'x3^2'};

        case 'gpr'
            Phi = [];
            termNames = {};

        otherwise
            error('Unknown basis: %s', basisName);
    end
end
