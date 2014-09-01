function obj = detrend(varargin)
% DETREND - Detrend M/EEG data using a polynomial filter

myFilter = filter.polyfit('Order', 10);

mySel1 = pset.selector.sensor_class('Class', {'EEG', 'MEG'});
mySel2 = pset.selector.good_data;

obj = meegpipe.node.filter.new(...
    'DataSelector',     pset.selector.cascade(mySel1, mySel2), ...
    'Filter',           myFilter, ...
    'EpochDurReport',   Inf, ...
    'NbChannelsReport', 5, ...
    'ShowDiffReport',   true, ...
    varargin{:});

end