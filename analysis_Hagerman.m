function [target, noise] = analysis_Hagerman(results, varargin)
%% DESCRIPTION:
%
%   This function analyzes Hagerman-style (that is, phase inversion
%   technique) recordings to estimate the target/noise tracks, estimate
%   the noise floor of the playback/recording loop (this includes
%   environmental noise), and estimates the signal to noise ratio of the
%   input and output signals.
%
% INPUT:
% 
%   results:   data information. Can be one of the following formats
%               - results structure from SIN_runTest.
%               - string, path to a mat file containing the results 
%               structure. 
%
% Parameters:
%
%   Parameters for Hagerman Labeling:
%
%   'target_string': 
%   'noise_string': 
%   'inverted_string':
%   'original_string':
%   
%   'pflag':     integer, sets plotting level. This parameter is inherited
%                by secondary functions as well. At time of writing, 2 is
%                the highest level of plotting detail. 0 means no plots. 
%
%   'align':    bool, if set, attempts to temporally realign target/noise
%               pairs (e.g., the target estimates created in two ways will
%               be temporally realigned). If false, no realignment done. 
%
%   'absolute_noise_floor': string. This string is compared against
%                           all file names in the playback list. If a match
%                           is found, then this file is assumed to contain
%                           the absolute noise floor estimate, however the
%                           user decides to estimate it. This is typically
%                           done by recording "silence" for some period of
%                           time. 
%
% OUTPUT:
%
%   results:    modified results structure with analysis results field
%               populated.
%
% Development:
%
%   1) Allow users to provide a string with tags in it (e.g.,
%   %%target_string%% to denote where labels should be in the file name. A
%   regular expression, perhaps? Currently, this is hard-coded. Could cause
%   some issues down the road if we decide to change the file name format. 
%
% Christopher W Bishop
%   University of Washington
%   9/14

%% GET INPUT PARAMETERS
d=varargin2struct(varargin{:});

%% GATHER FILENAMES AND RECORDINGS
filenames = results.RunTime.sandbox.playback_list; 
recordings = results.RunTime.sandbox.mic_recording; 

%% GET SAMPLING RATE/NUMBER OF CHANNELS
sampling_rate = results.RunTime.player.record.device.DefaultSampleRate;
number_of_channels = size(recordings{1}, 2); % assumes all recordings have the same number of channels 

%% QUICK SAFETY CHECK
if numel(filenames) ~= numel(recordings)
    error('Number of filenames does not match the number of recordings'); 
end % if numel(fnames)

%% GROUP FILENAMES AND DATA TRACES
%   The data traces are the recordings written to the structure
for i=1:numel(filenames)
    data{i,1} = filenames{i};
    data{i,2} = recordings{i};
end % for i=1:numel ...

%% LOOK FOR NOISE FLOOR RECORDING
%   In some instances, the user may acquire an absolute noise floor
%   estimate - that is, a recording of "silence" to estimate the noise
%   levels in the sound playback/recording loop and any ambient noise. This
%   can be helpful for SNR estimation and correction or offline filter
%   design to remove (ambient) noise contaminants. 
noise_floor_mask = ~cellfun(@isempty, strfind(filenames, d.absolute_noise_floor)); 

% Sanity check to make sure there's only one noise floor estimate
if numel(noise_floor_mask(noise_floor_mask)) > 1
    error('More than one match found for noise floor estimation. Multiple estimates not supported (yet)');
end 

% Save the noise floor recording for further analysis below
noise_floor_recording = recordings{noise_floor_mask}; 

%% CLEAN FILENAMES FOR MATCHING
%   We want to strip the filenames of the target/noise inversion
%   information and just match the basenames. First step is to get the base
%   names. 
basename = cell(numel(filenames), 1); 
for i=1:numel(filenames)
    
    % Get the current file name
    tmp = filenames{i};
    
    % Remove all 4 possible naming combinations
    tmp = strrep(tmp, [d.target_string d.original_string d.noise_string d.original_string], ''); % +1, +1
    tmp = strrep(tmp, [d.target_string d.original_string d.noise_string d.inverted_string], '');  % +1, -1
    tmp = strrep(tmp, [d.target_string d.inverted_string d.noise_string d.inverted_string], '');  % -1, -1
    tmp = strrep(tmp, [d.target_string d.inverted_string d.noise_string d.original_string], '');  % -1, +1
    
    basename{i,1} = tmp;
    
    clear tmp
end % for i=1:numel(fnames)

%% GROUP FILES BY BASENAME
%   Now that we have the basenames for the original files, we can figure
%   out which recordings should be grouped together based on the filename
%   alone. 

% fgroup is a grouping variable
file_group =zeros(numel(filenames),1); 

% while ~isempty(basename)
for i=1:numel(basename)
    mask = false(numel(basename),1); 
    
    ind = strmatch(basename{i}, basename, 'exact'); 
    if file_group(ind(1)) == 0
       file_group(ind) = max(file_group)+1; 
    end % if fgroup
    
end % for i=1:numel(fnames)

%% NOW TOSS OUT GROUPS WITH FEWER THAN 4 SAMPLES
%   - Fewer than 4 samples will be found for noise floor matching. 
%   - This will implicitly remove the noise floor estimate, if it's here. 
number_of_groups = unique(file_group);
for i=1:numel(number_of_groups)
    
    if numel(file_group(file_group == number_of_groups(i))) < 4
        file_group(file_group==number_of_groups(i)) = NaN;
    end % if numel ...
    
end  % for i=1:numel(grps)

%% FOR REMAINING GROUPS, LOOP THROUGH AND PERFORM ANALYSES

% Number of groups tells us how many file groupings we have. This should
% correspond to the number of SNRs we have recorded. 
number_of_groups = unique(file_group(~isnan(file_group))); 

% snr will tell us the SNR corresponding to each group. This is discovered
% below using some simple string matching. Granted, it assumes the filename
% structure (which is a little silly), but making this more flexible would
% probably take a lot of time to do. CWB isn't up for it at the moment. 
snr_theoretical = nan(numel(number_of_groups), 1);

for i=1:numel(number_of_groups)
    
    % Create logical mask
    mask = false(numel(file_group),1);
    mask(file_group == number_of_groups(i)) = true; 
    mask = find(mask); % convert to indices.
    
    % Get the filenames from the data variable. Will use this to figure out
    % which data traces go where
    group_filenames = {data{mask,1}}; 
    
    % What's the SNR for this group of recordings?
    %   - We'll assume theres an SNR label in a ';' delimited file name.
    %   The SNR should be the first element in one segment of the file name
    %   - Also does a basic sanity check to (re)confirm that all files in
    %   this group have the same SNR according to this (clunky) algorithm
    for k=1:numel(group_filenames)
        
        % Get the individual sections
        filename_sections = strsplit(group_filenames{k}, ';'); 
        
        % Now find the SNR segment
        %   - This looks super complicated ... and it is. BUT seems to work
        %   - Should be insensitive to "SNR" string's case (snr or SNR both
        %   recognized) 
        snr_string = filename_sections(~cell2mat(cellfun(@isempty, strfind(cellfun(@lower, filename_sections, 'uniformoutput', false), 'snr'), 'uniformoutput', false))');
        
        % Get the leading digit. This should be our SNR value
        snr_string = regexp(snr_string,['\d+\.?\d*'],'match');
        temp_snr(k) = str2double(snr_string); 
        
    end % for i=1:numel(group_filenames
    
    % Check to make sure there's only ONE SNR in this file group
    if numel(uniqe(temp_snr)) ~= 1
        error('Multiple SNRs found in this file group');
    else
        % Assign the SNR value to our SNR array. We'll use this below for
        % plotting/analysis purposes. 
        snr_theoretical(i) = unique(temp_str); 
    end % if numel(unique ...
    
    % Create a variable to store data traces
    %   Col 1 = +1/+1
    %   Col 2 =  +1/-1
    %   Col 3 = -1/-1
    %   Col 4 = -1/+1    
    
    % Find +1/+1
    ind = findcell(group_filenames, [d.target_string d.original_string d.noise_string d.original_string]);
    oo = data{mask(ind), 2}; 
    
    % Find +1/-1
    ind = findcell(group_filenames, [d.target_string d.original_string d.noise_string d.inverted_string]);
    oi = data{mask(ind), 2}; 
    
    % Find -1/-1
    ind = findcell(group_filenames, [d.target_string d.inverted_string d.noise_string d.inverted_string]);
    ii = data{mask(ind), 2}; 
    
    % Find -1/+1
    ind = findcell(group_filenames, [d.target_string d.inverted_string d.noise_string d.original_string]);
    io = data{mask(ind), 2};     
    
    % Calculate the target two ways
    target{i} = [Hagerman_getsignal(oo, oi, 'fsx', sampling_rate, 'fsy', sampling_rate, 'pflag', logical(d.pflag)) Hagerman_getsignal(io, ii, 'fsx', sampling_rate, 'fsy', sampling_rate, 'pflag', logical(d.pflag)).*-1]; 
    
    % Rinse and repeat for noise estimates
    noise{i} = [Hagerman_getsignal(oo, io, 'fsx', sampling_rate, 'fsy', sampling_rate, 'pflag', logical(d.pflag)) Hagerman_getsignal(oi, ii, 'fsx', sampling_rate, 'fsy', sampling_rate, 'pflag', logical(d.pflag)).*-1]; 
    
    if d.align
        % Check temporal alignment of the two target estimates
        [aligned_noise1, aligned_noise2, noise_lag] = ...
            align_timeseries(noise{i}(:,1), noise{i}(:,2), 'xcorr', 'fsx', sampling_rate, 'fsy', sampling_rate, 'pflag', d.pflag);

        % Check temporal alignment of the two target estimates
        [aligned_target1, aligned_target2, target_lag] = ...
            align_timeseries(target{i}(:,1), target{i}(:,2), 'xcorr', 'fsx', sampling_rate, 'fsy', sampling_rate, 'pflag', d.pflag);

        if target_lag ~= 0

            % If the signals are misaligned, make the user aware that there's
            % some jitter in his/her system, then kick back the realigned time
            % series.
            warning(['Target signals temporally misaligned by ' abs(num2str(target_lag)) ' sample. Returning realigned data.'])

            target{i} = [aligned_target1 aligned_target2];

        end % if target_lag ~= 0

        if noise_lag ~= 0

            % If the signals are misaligned, make the user aware that there's
            % some jitter in his/her system, then kick back the realigned time
            % series.
            warning(['Noise signals temporally misaligned by ' abs(num2str(target_lag)) ' sample. Returning realigned data.'])

            noise{i} = [aligned_noise1 aligned_noise2];

        end % if noise_lag ~= 0
        
    end % if d.align
    
end % for i=1:numel(grps)

% By now, we have an extracted noise and target signal for each SNR level
% (group) and each recording channel. The following code will do additional
% calcuations (e.g., SNR estimates).

% Calculate empirical SNR
%   - This should ultimately use James Lewis's code to calculate wide- and
%   narrow-band SNR in pascals and dB SNR all while incorporating
%   individual audiograms. 
%   - But, as a first pass, we'll do some simple RMS calculations for SNR
%   estimates. 

% function signal = extract_data(x, y, varargin)
% %% DESCRIPTION:
% %
% %   Function to do basic data extraction using Hagerman style phase
% %   inversion calculations.
% %
% % INPUT:
% %
% %   x:  input series 1
% %   y:  input series 2 
% %
% % Paramters:
% %
% %   'fsx':  sampling rate of input series 1
% %   'fsy':  sampling rate of input series 2
% %   'pflag':    integer, plotting level (1 = make plots, 0 = no plots)
% %
% % OUTPUT:
% %
% %   signal: signal time series.
% %
% % Christopher W Bishop
% %   University of Washington
% %   10/14
% 
% %% GET INPUT PARAMETERS
% d = varargin2struct(varargin{:});
% 
% % Extract time series