
function isEfficient = is_pareto_efficient(points)
%IS_PARETO_EFFICIENT Return a logical mask for non-dominated points.
% Assumes all objectives are to be minimized.

    n = size(points, 1);
    isEfficient = true(n, 1);

    for i = 1:n
        if ~isEfficient(i)
            continue;
        end

        for j = 1:n
            if i == j
                continue;
            end

            if all(points(j, :) <= points(i, :)) && any(points(j, :) < points(i, :))
                isEfficient(i) = false;
                break;
            end
        end
    end
end
