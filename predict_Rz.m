
function y = predict_Rz(models, x)
%PREDICT_RZ Convenience wrapper for Rz prediction.
    y = predict_response_model(models.Rz, x);
end
