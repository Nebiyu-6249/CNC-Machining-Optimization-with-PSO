
function y = predict_response_model(model, x)
%PREDICT_RESPONSE_MODEL Predict a response from a fitted surrogate model.
%
% Inputs:
%   model - selected model struct
%   x     - 1x3 or Nx3 matrix [Vc, f, DOC]
%
% Output:
%   y     - predicted response

    if istable(x)
        x = x{:,:};
    end

    x = double(x);

    if size(x, 2) ~= 3
        error('Input x must be 1x3 or Nx3 with columns [Vc, f, DOC].');
    end

    % Clamp x to the permitted design space
    lb = model.bounds.lb(:)';
    ub = model.bounds.ub(:)';
    x = min(max(x, lb), ub);

    if strcmpi(model.fitType, 'gpr')
        y = predict(model.gprModel, x);
        return;
    end

    [Phi, ~] = build_design_matrix(x, model.basis, model.bounds);
    y = Phi * model.beta;
end
