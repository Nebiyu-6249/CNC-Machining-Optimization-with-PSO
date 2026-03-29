
function y = predict_Rt(models, x)
%PREDICT_RT Convenience wrapper for Rt prediction.
    y = predict_response_model(models.Rt, x);
end
