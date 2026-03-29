
function y = predict_ToolWear(models, x)
%PREDICT_TOOLWEAR Convenience wrapper for tool wear prediction.
    y = predict_response_model(models.ToolWear, x);
end
