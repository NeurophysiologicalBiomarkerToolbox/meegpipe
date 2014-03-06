function myPipe = cleaning_pipeline(varargin)

import meegpipe.*;

import pset.selector.sensor_class;
import pset.selector.cascade;
import pset.selector.good_data;

USE_OGE = true;
DO_REPORT = true;
QUEUE = 'short.q';

nodeList = {};

%% Import
myImporter = physioset.import.physioset;
myNode = node.physioset_import.new('Importer', myImporter);
nodeList = [nodeList {myNode}];

%% copy data
% We create a temporary on the LOCAL temp dir. This should speed up
% processing considerably when the job is running at a node other than
% somerenserver (where the raw data is located).
myNode = node.copy.new('Path', @() tempdir);
nodeList = [nodeList {myNode}];

%% HP filter
mySel =  cascade(...
    sensor_class('Class', 'EEG'), ...
    good_data ...
    );
myNode = node.filter.new(...
    'Filter',         @(sr) filter.hpfilt('Fc', 1/(sr/2)), ...
    'DataSelector',   mySel, ...
    'Name',           'HP-filter-1Hz');
nodeList = [nodeList {myNode}];

% %% Node: remove large signal fluctuations using a LASIP filter
% 
% % Setting the "right" parameters of the filter involves quite a bit of
% % trial and error. These values seemed OK to me but we should check
% % carefully the reports to be sure that nothing went terribly wrong. In
% % particular you should ensure that the LASIP filter is not removing
% % valuable signal. It is OK if some residual noise is left after the LASIP
% % filter so better to be conservative here.
% myScales =  [20, 29, 42, 60, 87, 100, 126, 140, 182, 215, 264, 310, 382];
% 
% myFilter = filter.lasip(...
%     'Decimation',       12, ...
%     'GetNoise',         true, ... % Retrieve the filtering residuals
%     'Gamma',            15, ...
%     'Scales',           myScales, ...
%     'WindowType',       {'Gaussian'}, ...
%     'VarTh',            0.1);
% 
% % This object especifies which subset of data should be processed by the
% % node. In this case we want to process only the EEG data, and ignore any
% % other modalities.
% mySel = pset.selector.sensor_class('Class', 'EEG');
% 
% myNode = node.filter.new(...
%     'Filter',           myFilter, ...
%     'Name',             'lasip', ...
%     'DataSelector',     mySel, ...
%     'ShowDiffReport',   true ...
%     );
% 
% nodeList = [nodeList {myNode}];

%% Reject broken channels (a priori info)
mySel = pset.selector.sensor_label({'EEG 133$', 'EEG 145$', 'EEG 165$', ...
    'EEG 174$', 'EEG REF$'});
myCrit = node.bad_channels.criterion.data_selector.new(mySel);
myNode = node.bad_channels.new(...
    'Criterion', myCrit);
nodeList = [nodeList {myNode}];

%% bad channel rejection (using variance)
minVal = @(x) median(x) - 35;
maxVal = @(x) median(x) + 12;
myCrit = node.bad_channels.criterion.var.new('Min', minVal, 'Max', maxVal);
myNode = node.bad_channels.new(...
    'Criterion',        myCrit);
nodeList = [nodeList {myNode}];

%% bad epochs
myNode = node.bad_epochs.sliding_window(1, 2);
nodeList = [nodeList {myNode}];

%% Merge discontinuities created by bad epoch rejection
mySel =  cascade(...
    sensor_class('Class', 'EEG'), ...
    good_data ...
    );
myNode = node.smoother.new(...
    'DataSelector',  mySel, ...
    'MergeWindow',   0.15);

nodeList = [nodeList {myNode}];

%% LP filter
mySel =  cascade(...
    sensor_class('Class', 'EEG'), ...
    good_data ...
    );
myNode = node.filter.new(...
    'Filter',           @(sr) filter.lpfilt('Fc', 70/(sr/2)), ...
    'DataSelector',     mySel, ...
    'Name',             'LP-filter-70Hz');
nodeList = [nodeList {myNode}];

%% Node: Downsample
myNode = node.resample.new('OutputRate', 250);
nodeList = [nodeList {myNode}];

%% Node: remove PWL noise
myNode = aar.pwl.new('IOReport', report.plotter.io);
nodeList = [nodeList {myNode}];

%% Node: ECG
myNode = aar.ecg.new;
nodeList = [nodeList {myNode}];

%% Sparse sensor noise
myNode = aar.sensor_noise.sparse_sensor_noise(...
    'Max',      125, ...
    'IOReport', report.plotter.io);
nodeList = [nodeList {myNode}];

%% low-pass filter
myNode = node.filter.new(...
    'Filter',           @(sr) filter.lpfilt('Fc', 42/(sr/2)), ...
     'DataSelector',    mySel, ...
    'Name',             'LP-filter-42Hz');
nodeList = [nodeList {myNode}];

%% Node: Reject EOG components using their topography
myNode = aar.eog.topo_generic(...
    'RetainedVar',      99.85, ...
    'MinCard',          2, ...
    'MaxCard',          10, ...
    'IOReport',         report.plotter.io);
nodeList = [nodeList {myNode}];

%% supervised BSS
myNode = aar.bss_supervised_single_node;
nodeList = [nodeList {myNode}];

% %% Node: EMG correction (for LATER!)
% myNode = node.bss.emg(...
%     'CorrectionTh',     60, ...
%     'WindowLength',     10, ...
%     'WindowOverlap',    75, ...
%     'ShowDiffReport',   true, ...
%     'IOReport',         report.plotter.io);
% nodeList = [nodeList {myNode}];

%% Pipeline
myPipe = node.pipeline.new(...
    'NodeList',         nodeList, ...
    'Save',             true, ...
    'Parallelize',      USE_OGE, ...
    'GenerateReport',   DO_REPORT, ...
    'Name',             'cleaning_pipe', ...
    'Queue',            QUEUE, ...
    'TempDir',          @() tempdir, ... 
    'FakeID',           'ad49a8', ...
    varargin{:} ...
    );

