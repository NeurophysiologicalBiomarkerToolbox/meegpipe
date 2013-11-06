function featVal = systolic_bp(data, sr)

if size(data,1) > 1,
    warning('abp:MultipleABPleads', ...
        '%d ABP leads found: using only the first one', size(data,1));
end

co = co_features(data(1,:), sr);

featVal = co(1);



end