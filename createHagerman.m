function createHagerman(varargin)
%% DESCRIPTION:
%
%   Function to create stimuli for Hagerman recordings. The basic idea is
%   to provide a method of estimating SNR, a flag for holding the noise or
%   speech track constant, and a naming scheme to use to save the output
%   files.
%
%   Hagerman stimuli for Project AD: HA SNR are comprised of ~1 minute of
%   concat_target_trackenated HINT sentences (e.g., List01 - List03) paired with one of
%   several noise types (speech-shaped noise (SSN) and ISTS). 
%
%   Other flags provide information regarding the number of noise channels
%   to create and what time delay should be applied to each of the noise
%   channels - recall that SSN and ISTS are single channel files
%
%   Note: noise and target tracks are assumed to be single channel. If they
%   are stereo, the second channel is used. (Confusing, I know, but the
%   HINT stims that CWB have the target in the second channel). 
%
% INPUT:
%
% Parameters:
%
%   File input and preprocessing:
%
%   'target_tracks':  cell array, each element contains the path to a file
%                   that will ultimately be part of the target signal
%                   (e.g., speech track).
%
%   'target_input_mixer':     Dx1 array, where D is the number of channels in the wav
%                   files and 1 is the number of resulting target channels 
%                   (this can be 1 and only 1 as coded). This is the data
%                   loaded from WAV files (or other media sources) are
%                   matrix multiplied with this mixer to create a
%                   single-channel, mixed signal that will be come the
%                   "target track".
%
%                   *Note*: the mixer values for target_input_mixer and noise_input_mixer should
%                   *always* be position. So should the target_output_mixer and
%                   noise_output_mixer. Including negative numbers will lead to
%                   mislabeled file generation. CWB has placed a couple of
%                   safeguards against this, but you're the first line of
%                   defense.
%
%   'noise_track':   string, path to the noise track. 
%
%   'noise_input_mixer':     like target_mixer but applied to the noise sample.
%
%   'remove_silence':    bool, if set, removes the silence from beginning
%                       and end of noise and target samples before further
%                       processing. If set to TRUE, must also set
%                       amplitude_threshold parameter. 
%
%   'amplitude_threshold':    double, absolute amplitude threshold to use to
%                   define leading and trailing periods of silence.
%
%   SNR Calculation:
%
%   'snrs':         double array, desired SNRs. 
%
%   Noise windowing/timing shifts
%
%   'noise_window_sec':apply an X sec wifndowing function to the beginning and
%                   end of noise track. If user does not want any
%                   windowing, set to 0. Uses a Hanning windowing function
%
%   'noise_shift':   the temporal offset applied to noise between sequential
%                   output channels (in sec). 
%
%   File Output:
%
%   'output_base_name': string, full path to base file name. (e.g.,
%               fullpath('playback', 'Hagerman', 'mywav.wav'); 
%

%
%   'bit_depth': bit depth for output file (e.g., 24)
%
%   'gap_range':         two-element array, specifies the temporal jitter
%                       between the end of of the previous target file
%                       and the subsuquent target. Think of this as
%                       introducing a variable (or fixed) silent period
%                       between target sentences. 
%   'target_output_mixer':    1xP array, where P is the number of output channels of 
%                   thre returned data. Each coefficient weights and adds
%                   the input target track to the output track
%
%   'noise_output_mixer'     1xP array, like target_output_mixer about, but mixes input noise
%                   track into output tracks. 
%
%   'write_signal_mask':   bool, if true, then the function will write a
%                           "companion file" for each output file. This is
%                           a binary mask that can be later loaded and used
%                           to mask a recording to limit RMS estimates to
%                           the periods during which a signal is actually
%                           present. 
%
% Visualization Parameters:
%
%   Noise Floor Estimation:
%
%   Hagerman recordings can be affected by the noise floor of our
%   playback/recording loop, so it would be wise to estimate the noise
%   floor in some way. To do this, CWB will write an additional WAV file
%   containing just zeros. This file will be presented and a recording
%   gathered, which will allow us to estimate the noise floor of our
%   playback/recording loop. Should be useful.
%
%   'estimate_noise_floor':    bool, if set, write noise floor estimation file. If
%                       set, user must also define 'noise_floor_sec'
%                       parameter below.
%
%   'noise_floor_sec':    double, duration of recording desired for noise
%                       floor estimation in seconds. 
%
% Development:
%
%   1) CWB must recall that he needs to match the long-term spectrum of the
%   noise sample to the actual target stimuli used.
%
% Christopher W. Bishop
%   University of Washington
%   9/14

%% MASSAGE INPUTS
d=varargin2struct(varargin{:}); 

%% CHECK MIXERS
%   Mixers must only have zeros and positive numbers. Negative numbers will
%   throw off the (rather stupid) naming scheme CWB came up with at the
%   end. CWB thinks he'll end up regretting the quick fix ... CWB in the
%   future, if you're reading this and scratching your head, then you knew
%   you were being an idiot when you wrote this. Silly, silly bear.
if any(d.target_input_mixer==-1) || any(d.noise_input_mixer==-1) || any(d.target_output_mixer==-1) || any(d.noise_output_mixer==-1)
    error('Do not use negative values in your mixing matrices. Bad user! Read the help, please.');
end % if any ...

%% LOAD AND RESAMPLE STIMULI
%   Load stimuli from file and resample to match user specified sampling
%   rate (FS).

% concat_target_trackenate stimuli into a single time series. This is later used in RMS
% estimation routines. 
[concat_target_track, target_fs, target_track] = concat_audio_files(d.target_tracks, ...
    'remove_silence', true, ...
    'amplitude_threshold', d.amplitude_threshold, ...
    'mixer', d.target_input_mixer); 

% Only load noise stimulus if user specifies it
if ~isempty(d.noise_track)
    
    % Load noise track
    [~, noise_fs, noise_track] = concat_audio_files(d.noise_track, ...
    'remove_silence', true, ...
    'amplitude_threshold', d.amplitude_threshold, ...
    'mixer', d.noise_input_mixer); 
    
    % Sampling rate error check
    if noise_fs ~= target_fs, error('Sampling rates do not match'); end 
   
end % if ~isempty(d.noise_track) 

% Match the duration of the noise track and target track
if size(noise_track, 1) < size(target_track, 1)
    
    % If the noise track is too short, then replicate it 
    noise_track = repmat(noise_track, ceil(size(target_track,1)./size(noise_track,1)));
    
end % if size ...

% Now trim it to match the duration of the target track
noise_track = noise_track(1:size(target_track,1), :); 

% Calculate RMS of target and noise track
target_rms = rms(concat_target_track); 
noise_rms = rms(noise_track); 

% Equate noise and target levels
%   We need the SPL (measured as dB(rms) to be equal. That is, we need to
%   scale the noise such that we have 0 dB
% % Should we remove silence from noise as well?
% if ~isempty(nstim)    
%     
%     % Estimate RMS of target and noise track
%     rmstarg = rms(concat_target_track); 
%     rmsnoise = rms(noiseref);
% 
%     % If holdtargSPL is set, then scale the noise to target
%     scale = db2amp(db(rmstarg) - db(rmsnoise)); 
%     nstim = nstim.*scale; % scale the noise stimulus. 
%     
% end % ~isempty(nstim)

%% WRITE concat_target_trackENATED FILE?
%   If the user suggests it, then we need to write the concat_target_trackenated file
%   used for scaling estimate to file. This may be useful when playing
%   stimuli back in sound field for SPL measurement.

% Clear potentially confusing variables
clear concat_target_track noiseref noise

% Set random number generator state to a constant so we get the same
% stimulus every time 
%   Will likely help prevent errors or oversights by CWB down the road
rng(0, 'twister'); % resets default state of random number generate

% Generate output target track
tout = []; % target output track
signal_mask = []; % the signal mask will be TRUE everywhere there's a signal and FALSE where we input silence
for i=1:numel(tstim)
    
    % Estimate silent periods at beginning and end of sound
    if i>1
        leadsamps = size(tstim{i-1}, 1) - size(threshclipaudio(tstim{i-1}, d.amplitude_threshold, 'begin'),1);
    else 
        leadsamps = 0; 
    end 
    
    % Always calculate lag samps of current stimulus
    lagsamps = size(tstim{i}, 1) - size(threshclipaudio(tstim{i}, d.amplitude_threshold, 'end'),1); 
    
    % Get total number of zeroed samples to add    
    zsamps = round((d.gap_range(1) + diff(d.gap_range)*rand(1))*d.output_fs) - (leadsamps + lagsamps);   
    
    % Create zero-padded stimulus
    zpad = [tstim{i}; zeros(zsamps, size(tstim{i}, 2))]; 
    
    % Create zero padded track
    %   Zeros are how we account for silent period after sound offset
    tout = [tout; zpad]; 
    
    % Make a signal_mask
    %   This is one everywhere a "signal" has been added. Note, however,
    %   that this requires a signal to be present in the data to begin with
    %   - so it's a bit of a misnomer. 
    %
    %   signal_mask is written as an extra channel in the data. 
%     if d.write_signal_mask
        signal_mask = [signal_mask; true(size(tstim{i})); false(zsamps, size(tstim{i},2))];        
%         tout = [tout; signal_mask];
%     end % if d.write_signal_mask
    
    clear zpad
    
end % for i=1:numel(tstim)

% Mix tout with target_output_mixer
tout = tout * d.target_output_mixer; 

%% CREATE NOISE OUTPUT (nout)
%   - Remix the audio and implement time delays using remixaudio
%   - Fade noise samples in and out on all channels. 
if ~isempty(nstim)
    % Create matching noise sample
    nout = repmat(nstim, ceil(size(tout,1)./size(nstim,1)), 1); % repmat it to match
    nout = nout(1:size(tout,1)); % truncate to match

    % Fade noise in/out
    nout = fade(nout, d.output_fs, true, true, @hann, d.noise_window_sec); 
    
    % Mix noise and apply time shift
    nout = remixaudio(nout, 'fsx', d.output_fs, 'mixer', d.noise_output_mixer, 'toffset', d.noise_shift, 'writetofile', false);  
    
end % if ~isempty(nstim)

% Now, assuming we're at 0 dB SNR, create requested SNR outputs
for i=1:numel(d.snrs)
    
    % output file name
    [PATHSTR,NAME,EXT] = fileparts(d.output_base_name);
    
    % Create 4 combinations of polarity 
    %   target*1, noise*1: TorigNorig
    %   target*-1, noise*1: TinvNorig
    %   target*-1, noise*-1:    TinvNinv
    %   target*1, noise*-1: TorigNinv
    invmixer = [[1 1]; [1 -1]; [-1 1]; [-1 -1]];
    
    for n=1:size(invmixer,1)
        % Scale noise, mix to create output track
        if ~isempty(nstim)     
            % We have to multiply the SNR by -1 since we are holding th
            % speech track constant, but changing the noise. 
            out = tout.*invmixer(n,1) + nout.*db2amp(d.snrs(i).*-1).*invmixer(n,2);
        else
            out = tout.*invmixer(n,1);
        end % out
        
        % Append signal mask as the last channel in audio file
        if d.write_signal_mask
            out = [out signal_mask];
        end % if d.write_signal_mask
        
        % Generate target description string
        if sign(invmixer(n,1))==1
            tstr = 'Torig';
        elseif sign(invmixer(n,1))==-1
            tstr = 'Tinv';
        else
            error('I broke');
        end %if ...
        
        % Generate Noise description string
        if sign(invmixer(n,2))==1
            nstr = 'Norig';
        elseif sign(invmixer(n,2))==-1
            nstr = 'Ninv';
        else
            error('I broke');
        end %if ...
        
        % Make file name
        fname = fullfile(PATHSTR, [NAME ';' num2str(d.snrs(i)) 'dB SNR;' tstr nstr EXT]);
        
        % Write file
        audiowrite(fname, out, d.output_fs, 'BitsperSample', d.bit_depth); 
        
        clear out
    end % 
    
end % for i=1:d.snrs 

%% NOISE FLOOR ESTIMATION?
%   Create WAV file with just zeros for noise floor estimation.
if d.estimate_noise_floor
    
    % Number of zero samples
    nsamps = round(d.noise_floor_sec * d.output_fs);
    
    % Make zeros in all output tracks
    out = zeros(nsamps, size(d.target_output_mixer,2));
    
    % Write file
    fname = fullfile(PATHSTR, [NAME '(noise floor)' EXT]);
    
    % Write file
    audiowrite(fname, out, d.output_fs, 'BitsperSample', d.bit_depth); 
    
end % end 