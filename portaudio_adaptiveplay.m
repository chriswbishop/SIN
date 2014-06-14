function [results, status]=portaudio_adaptiveplay(X, varargin)
%% DESCRIPTION:
%
%   This function is designed to allow adaptive audio playback. The
%   adaptive audio playback can be done in several modes and is reasonably
%   modular. The basic flow goes something like this.
%
%           1. Present a sound.
%
%           2. Collect some form of information via a modcheck (e.g., a
%           button press or scoring information)
%
%           3. Pass the output of the modcheck to a modifier
%
%           4. The modifier modifies that upcoming playback data (e.g.,
%           makes a speech stream louder)
%
%           5. The process is repeated until all stimuli are presented.
%
% INPUT:
%
%   X:  cell array of file names to wav files. 
%
% Parameters:
%
%   'bock_dur':     data block size in seconds. The shorter it is, the
%                   faster the adaptive loop is. The longer it is, the less
%                   likely you are to run into buffering problems. 
%
%   'record_mic':   bool, set to record the playback during each trial.
%                   If set and the adaptive_mode is 'bytrial', be sure that
%                   the recording device has a very long buffer (greater
%                   than the total trial + response time + a healthy
%                   window in case a subject nods off). If adaptive_mode is
%                   set to 'continuous', then the recording buffer is
%                   emptied during playback and can be much shorter.
%
%   'randomize':    bool, set to shuffle X (the playback list) before
%                   beginning adaptive play. 
%
%   'modcheck': function handle. This class of functions determines whether
%               or not a modification is necessary. At the time he wrote
%               this, CWB could imagine circumstances in which the same
%               modifier must be applied, but under various conditions. By
%               separating the functionality of 'modcheck' and 'modifier',
%               the user can create any combination. This should, in
%               theory, improve the versatility of the adaptive playback
%               system. 
%
%               'modcheck' can perform any type of check, but must be self
%               contained. Meaning, it (typically) cannot rely exclusively
%               on information present in the adaptive play control loop.
%               An example of a modcheck might go something like this.
%
%                   1. On the first call, create a keyboard queue to
%                   monitor for specific button presses.
%
%                   2. On subsequent calls, check the queue and determine
%                   if a specific button (or combination thereof) was
%                   pressed.
%
%                   3. If some preexisting conditions are met, then modify
%                   the signal. Otherwise, do not modify the signal.
%
%               Alternatively, a modcheck might do the following.
%
%                   1. On the first call, open a GUI with callback buttons
%                   for users to click on. 
%
%                   2. On successive calls, check to see if a button has
%                   been clicked. If it has, then return a modification
%                   code.
%
%               'modchecks' must accept a single input; a master structure
%               contained by portaudio_adaptiveplay. 
%
%               modchecks must return the following variables
%                   
%                   1. mod_code:    integer (typically) describing the
%                                   nature of the required modification.
%                                   This code is further interpreted by
%                                   the modifier (below).
%
%                   2. d:   an updated structure for
%                           portaudio_adaptiveplay. 
%
%   'modifier': function handle. This class of functions will modify the
%               output signal X when the conditions of 'modcheck' (see
%               above) are satisfied. The function can do just about
%               anything, but must conform to some general guidelines.
%
%                   1. The function must accept three inputs
%
%                           X:  the time series to alter
%
%                           mod_code:   a modification code. This will
%                                       prove useful when one of several
%                                       conditional modifications are
%                                       possible (e.g., making a sound
%                                       louder or quieter). 
%
%                           d:  the control structure from
%                               portaudio_adaptiveplay.m.
%
%                   2. The function must have three outputs
%
%                           Y:  the modified time series X
%
%                           d:  the updated adaptive play structure. 
%
%   'adaptive_mode':    string, describing how the modifications should be
%                       applied to the data stream. This is still under
%                       development, but different tests (e.g., HINT and
%                       ANL) need the modifications to occur on different
%                       timescales (between words or during a continuous
%                       playback stream). The hope here is to include
%                       various adaptive modes to accomodate these needs.
%
%                           'continuous': apply modifications in as close to
%                                       real time as possible. This will
%                                       depend heavily on the size on the
%                                       'block_dur' parameter above; the
%                                       longer the block_dur, the longer it
%                                       takes for the "real time" changes
%                                       to take effect. But if the
%                                       block_dur is too short, then you
%                                       run into other, irrecoverable
%                                       problems (like buffer underruns).
%                                       Choose your poison. 
%
%                           'bytrial':      apply modifications at the end 
%                                           of each playback file. (under
%                                           development). This mode was
%                                           intended to accomodate the 
%                                           HINT.       
%
%   'playback_mode':    string, specifies one of various playback modes.
%                           'looped':   a sound is looped infinitely or
%                                       until the player receives a kill
%                                       signal from somewhere. 
%                           'standard': each sound presented once and only
%                                       once in the order dictacted by
%                                       X (although this may be randomized
%                                       if 'randomize' flag set). 
%
%   'append_files':     bool, append data files into a single file. This
%                       might be useful if the user wants to play an
%                       uninterrupted stream of files and the timing
%                       between trials is important. (true | false;
%                       default=false);
%
%                       Note: Appending files might pose some problems for
%                       established modchecks and modifiers (e.g., for
%                       HINT). Use this option with caution. 
%
%   'stop_if_error':    bool, aborts playback if there's an error. At tiem
%                       of writing, this only includes a check of the
%                       'TimeFailed' field of the playback device status.
%                       But, this can be easily expanded to incorporate all
%                       kinds of error checks. (true | false; default=true)
%
%                       Note: at time of writing, error checking only
%                       applies to 'continuous' adaptive playback. 
%
%                       Note: the 'TimeFailed' field does not increment for
%                       buffer underruns. Jeez. 
%
%                       Note: The 'XRuns' field also does not reflect the
%                       number of underruns. E-mailed support group on
%                       5/7/2014. We'll see what they say.
%
%   'startplaybackat':  double, when to start playback relative to start of
%                       sound file (sec). To start at beginning of file, st
%                       to 0. (no default)
%
%   'mod_mixer':        D x P double matrix, where D is the number of
%                       data channels (that is, the number of channels
%                       in the wav files) and P is the number of
%                       physical channels (that is, the number of
%                       output channels on the playback device). This mixer
%                       is only applied to the (potentially) modulated 
%
%                       Here are a few examples
% 
%                       Example 1: Present only the first (of two)
%                       channels from a wav file to the first (of
%                       four) output channels on the sound card
%                           [ [1; 0] [0; 0] [0; 0] [0; 0] ]
% 
%                       Example 2: Present the first (of two) channels
%                       from a wav file to the first two (of four)
%                       physical channels in equal proportions. Note
%                       that CWB chose to scale down the sounds. This
%                       is to prevent clipping. The user should use
%                       whatever fits his or her needs. 
%                           [ [0.5; 0.5] [0.5; 0.5] [0; 0] [0; 0] ]
%
%                       The mod_mixer was added relatively late in
%                       development when CWB realized it was difficult if
%                       not impossible to determine the level at which a
%                       given sound was presented. This was because
%                       different modifiers altered the data serially and
%                       each tracked its changes independently of the
%                       others. Thus, it was tough to take all of this into
%                       account post-hoc. By adding in the mixer, CWB
%                       thought it would be possible to write modifiers
%                       that change the intensity of sound playback (e.g.,
%                       modifier_dBscale) to modify a single matrix that
%                       can then be easily tracked, plotted, etc. Also,
%                       calibration factors (like RMS normalization) can
%                       also be applied directly to the mixing matrix with
%                       seamless tracking over trials/stimuli/loops. 
%
%   'state':    player state when first launched. States may change, but
%               currently include :
%                   'run':  run the test/playback
%                   'pause': pause playback
%                   'exit':     player exit
%
% Windowing options (for 'continuous' playback only):
%
%   In 'continuous' mode, data are frequently ramped off or on (that is, fade
%   out or fade in) to create seamless transitions. These paramters allow
%   the user to specify windowing options, including a windowing function
%   (provided it's supported by matlab's "window" function) and a ramp
%   time.
%
%       'window_fhandle':function handle to windowing function. (default =
%                       @hann). See window.m for more options. 
%
%       'window_dur':   duration of windowing function. Too short may lead
%                       to popping or clicking in playback. Too long and
%                       it takes longer for adpative changes to occur
%                       (longer before the change "fades in"). 
%                       (seconds | default = 0.005 (5 msec))
%
% Unmodulated sound playback settings:
%
%   CWB originally tried to setup a slave device to manage a second audio
%   buffer, but after some basic tests, it became clear that the audio
%   playback quality was just too low. In fact, most attempts, even simply
%   playing back a sound of interest, crashed MATLAB completely. This
%   solution was not stable. So, CWB opted to allow users to grab a second
%   handle (and buffer) to the same physical device. Although this is not
%   strictly a "slave", it allows the user to present a sound that will not
%   be subjected to modchecks and modifiers. 
%
%   This addition was intended to allow the user to present a masker during
%   sound playback that would *not* be subjected to modchecks and
%   modifiers. 
%
%   At time of writing, only a single file can be presented as an
%   unmodulated sound. That is, the same sound is presented for each
%   element of X or, if unmod_playbackmode is set to 'looped', is looped
%   continuously throughout playback. 
%
%       'unmod_playback':   A single-element cell containing the filename
%                           of the wavfile to be be presented.
%
%       'unmod_channels':   a channel array similar to the
%                           'playback_channels' paramter described above,
%                           but 'slave_channels' only applies to the file
%                           specified by 'slave_playback'. (defaults to
%                           playback_channels)
%       
%       'unmod_playbackmode':   string, the method of unmod playback. This
%                               is still under development.
%                               (default='')
%                                   'looped':   Loop unmod playback. This
%                                               is useful when a masker
%                                               needs to be presented
%                                               constantly throughout an
%                                               otherwise independently
%                                               controlled target stream
%                                               (e.g., with HINT).
%
%                                   'stopafter':Stop the unmodulated noise
%                                               after each trial. If this
%                                               is set, both unmod_leadtime
%                                               and unmod_lagtime need to
%                                               be set. 
%
%       'unmod_leadtime':   double, how far in advance the slave device
%                           should be started relative to the modulated
%                           playback stream. (default=0 seconds). 
%                           This proved useful when administering the HINT. 
%                           This is implemented, but terribly crude and
%                           should not be used for precisely controlled
%                           relative timing (yet)
%
%       'unmod_lagtime':    Double, how long after modulated playback has
%                           stopped before stopping the unmodulated
%                           playback (secs) See notes on timing control for
%                           unmod_leadtime; same deal here - things aren't
%                           terribly precise yet. 
%       
% OUTPUT:
%
%   d:  data structure containing parameters and scored data. Fields depend
%       on the modifier and modcheck employed. 
%
% Development:
%
%   1. Add timing checks to make sure we have enough time to do everything
%   we need before the buffer runs out
%
%   13. Improve d.unmod_leadtime so the relative start times are reasonably
%   close. 
%
%   18. change unmod_playbackmode names to something more informative. 
%
%   19. Need additional precautions when monitoring keypresses in
%   'continuous' mode. If the user starts pressing keys before sounds play,
%   we won't have any record of those button presses (at present). 
%
%   20. Recorded responses are cut a little short. Most obvious in
%   continuous mode (tested with ANL). At the time, the recording device
%   had a delay of ~465 ms (MME)while playback had a delay of ~120 ms
%   (Windows Direct Sound). Probably need to compensate for any latency
%   differences to ensure high-fidelity (and complete) recordings. CWB
%   tried using "Direct Sound" recordings, but they were very crackly and
%   low quality. 
%
%   22. The relative timing of unmodulated sound playback depends not just
%   on the lead/lag settings, but *also* player.playback.block_dur. This
%   needs to be addressed (or accounted for) with scheduling. 
%
%   23. Add in check for continuous adaptive mode. Need to make sure that
%   the block_duration is shorter than our sound, otherwise we might as
%   well do a "bytrial" adjustment - in fact, that would probably be
%   cleaner. 
%
%   27. Need to handle the "unmodualted" noise in a smarter way. At
%   present, the unmodulated noise is handled independently of the
%   modulated output. Provided the "mixer" is available, it may be wise to
%   add the unmodulated sound as an additional channel to the modulated
%   data, then mix everything together. Not sure, though. Tough call. THis
%   approach will make it difficult to control relative timing as the test
%   is currently administered. But we might be able to setup a "scheduler"
%   for the playback device and add start/stop times. 
%
%   28. Add post-mixing modifiers. This will be useful when applying
%   channel-specific filtering to compensate for differences in device
%   playback channels (e.g., with different speakers).
%
%   29. Copy over presented data to a sandbox variable. This will serve as
%   a sanity check later since we will know *precisely* the data that were
%   sent to the sound card after the fact.
%
%   30. Add status return variable. Helpful if we encounter an error and
%   the invoking function needs to know about it. 
%
%   31. Modify so we can just record without playing sounds. A super dirty
%   way to do this would be to load a wavfile containing only zeros for the
%   requested duration of the recording. Might be the quickest fix. 
%
%   32. Make sure recording buffer checks work. Make a very short recording
%   buffer (shorter than 1 ms) and see if the checks catch the error. 
%
%   33. Recordings are truncated a bit (~200 ms) with MME recording and
%   DirectSound playback. Need to figure out how to fix this. Get ideas
%   from portaudio_playrec where CWB successfully accounted for these
%   delays. 
%       Here's the relevant check
%           size(Y,1) < size(X,1) + (playback_start_time - rec_start_time)*FS - ( rstatus.PredictedLatency + pstatus.PredictedLatency))
%           Y is the recording, X is the playback data. 
%
%   34. Code and allow for post-mixing modifiers. These will be useful for
%   filtering purposes or any other speaker-specific modifications that
%   must be applied to the (mixed) data sent to a single speaker. 
%
% Christopher W. Bishop
%   University of Washington
%   5/14

%% GATHER PARAMETERS
d=varargin2struct(varargin{:}); 

% Assign original input to results structure
results.UserOptions = d; 

% The player is made to work with a "SIN" style structure. If the user has
% defined inputs just at the commandline, then reassign to make it
% compatible.
if ~isfield(d, 'player')
    d.player = d; 
end % if

%% RANDOMIZE PLAYBACK LIST
playback_list=X; 
if d.player.randomize
    
    % Seed random number generator
    rng('shuffle', 'twister');
    
    % Shuffle playlist
    playback_list={playback_list{randperm(length(playback_list))}}; 
end % if d.player.randomize

%% INITIALIZE VOICE RECORDING VARIABLE
%   Trial recordings are placed in this cell array. 
d.sandbox.mic_recording = {}; % empty cell array for voice recordings (if specified) XXX not implemented XXX

%% SAVE DATE AND TIME 
%   Will help keep track of information later.
d.sandbox.start_time=now; 

% Get sampling rate for playback
FS = d.player.playback.fs; 

%% SET PLAYER STATE 
%   Finite state - player can only have a single state at a time
%
%   The state is set either internally (by the player) or altered by
%   secondary functions (like a modcheck or modifier). At least in theory.
%   This was not implemented fully when CWB wrote this comment.
%   
%   state:
%       'pause':    Pause playback
%       'run':      Play or resume playback
%       'exit':     Stop all playback and exit as cleanly as possible
% d.player.state = 'run'; 

%% SET ADDITIONAL VARIABLES
d.sandbox.data2play_mixed=[]; 

%% LOAD DATA
%
%   1. Support only wav files. 
%       - Things break if we accept single/double data series with variable
%       lengths (can't append data types easily using SIN_loaddata). So,
%       just force the user to supply wav files. That should be fine. 
%
%   2. Resample data to match the output sample rate. 
%
% Note: We want to load all the data ahead of time to minimize
% computational load during adaptive playback below. Hence why we load data
% here instead of within the loop below. 
t.datatype=2;

% Store time series in cell array (stim)
stim=cell(length(playback_list),1); % preallocate for speed.
for i=1:length(playback_list)
    
    [tstim, fsx]=SIN_loaddata(playback_list{i}, t);
    stim{i}=resample(tstim, FS, fsx); 
    
    % Check against mixer
    %   Only need to check against first cell of mixer because we completed
    %   an internal check on the mixer above.
    if size(d.player.mod_mixer, 1) ~= size(stim{i},2)
        error([playback_list{i} ' contains an incorrect number of data channels']); 
    end % if numel
    
end % for i=1:length(file_list)

clear tstim fsx;

% Add file_list to d structure
d.sandbox.playback_list=playback_list;

% Append playback files if flag is set
if d.player.append_files
    
    tstim=[];
    
    for i=1:length(stim)
        tstim=[tstim; stim{i}];
    end % for i=1:length(stim)
    
    clear stim;
    stim{1}=tstim; 
    clear tstim
    
end % if d.append_files

%% LOAD PLAYBACK AND RECORDING DEVICES
%   Only run InitializePsychSound if we can't load the device. Reduces
%   overhead. 
try
    % Get playback device information 
    [pstruct]=portaudio_GetDevice(d.player.playback.device);    % playback device structure
    [rstruct]=portaudio_GetDevice(d.player.record.device);      % recording device structure
catch
    InitializePsychSound; 
    [pstruct]=portaudio_GetDevice(d.player.playback.device);
    [rstruct]=portaudio_GetDevice(d.player.record.device); 
end % try/catch

% mod_mixer check
%   Need to make sure the number of columns in mod_mixer matches the number
%   of output channels
if size(d.player.mod_mixer, 2) ~= pstruct.NrOutputChannels, error('columns in mod_mixer does not match the number of output channels.'); end 

% Open the playback device 
%   Only open audio device if 'continuous' selected. Otherwise, device
%   opening/closing is handled through portaudio_playrec.
%
%   We now use buffered playback for both continuous and bytrial
%   adaptive playback. So, open the handle if either is selected
if isequal(d.player.adaptive_mode, 'continuous') || isequal(d.player.adaptive_mode, 'bytrial')
    
    % Open the unmodulated device buffer
    phand = PsychPortAudio('Open', pstruct.DeviceIndex, 1, 0, FS, pstruct.NrOutputChannels);
    
    % Open second handle for unmodulated sound playback
    if ~isempty(d.player.unmod_playback)        
        shand = PsychPortAudio('Open', pstruct.DeviceIndex, 1, 0, FS, pstruct.NrOutputChannels);
        uX = SIN_loaddata(d.player.unmod_playback); 
    end % if ~isempty(d.unmod_...
    
end % 

% Open a recording device if specified, specify as a recording device. 
if d.player.record_mic
    
    % Open recording device
    rhand = PsychPortAudio('Open', rstruct.DeviceIndex, 2, 0, FS, rstruct.NrInputChannels); 

    % Allocate Recording Buffer
    PsychPortAudio('GetAudioData', rhand, d.player.record.buffer_dur); 
    
    % Get rstatus - we might need this later to correct for differences in
    % predicted latency
    rstatus=PsychPortAudio('GetStatus', rhand);
    
end % if d.player.record_mic

%% PLAYBACK BUFFER INFORMATION
%   This information is only used in 'continuous' adaptive playback. Moved
%   here rather than below to minimize overhead (below this would be called
%   repeatedly, but these values do not change over stimuli). 
%
%   Use buffer information for 'bytrial' adaptive mode now as well. 
if isequal(d.player.adaptive_mode, 'continuous') || isequal(d.player.adaptive_mode, 'bytrial')
    % Create empty playback buffer
    buffer_nsamps=round(d.player.playback.block_dur*FS)*2; % need 2 x the buffer duration

    % block_nsamps
    %   This prooved useful in the indexing below. CWB opted to use a two block
    %   buffer for playback because it's the easiest to code and work with at
    %   the moment. 
    block_nsamps=buffer_nsamps/2; 

    % Find beginning of each "block" within the buffer
    block_start=[1 block_nsamps+1];
    
    % Start filling next block after first sample of this block has been
    % played
    refillat=ceil(1/block_nsamps);
%     refillat=round(block_nsamps/4); 
    
end % if isequal

% Create additional fields in 'sandbox'
%   Dummy values assigned as placeholders for intialization purposes. 
d.sandbox.trial=-1; % trial number
d.sandbox.nblocks=-1; % nblocks, the block number within the trial 
d.sandbox.block_num=-1; % block number we are in. 
d.sandbox.modifier_num=[];
d.sandbox.modcheck_num=1; % hard-coded for now since code only allows a single modcheck/trial (for now)

%% INITIALIZE MODCHECK and MODIFIER
%   These functions often have substantial overhead on their first call, so
%   they need to be primed (e.g., if a figure must be generated or a sound
%   device initialized).

% Call modcheck
[mod_code, d]=d.player.modcheck.fhandle(d);

% Initialized modifiers
%   Multiple modifiers possible
for modifier_num=1:length(d.player.modifier)
    
    % Update variable in sandbox
    d.sandbox.modifier_num=modifier_num;
    
    % Initialize modifier
    [~, d]=d.player.modifier{d.sandbox.modifier_num}.fhandle([], mod_code, d); 
    
end % for modifier_num

%% INITIALIZE BUFFER POSITION
%   User must provide the buffer start position (in sec). This converts to
%   samples
%
%   Added error check to only allow buffer start position to be set for
%   single file playback.
if d.player.startplaybackat ~= 0 && size(stim, 1) ~= 1
    error('Cannot initialize start position to non-zero value with multiple playback files');
else
    buffer_pos = round(d.player.startplaybackat.*FS); 
end % if d.player ...

for trial=1:length(stim)

    %% BUFFER POSITION
    if trial == 1
        buffer_pos = buffer_pos + 1; % This starts at the first sample specified by the user.     
    else
        % Note: this might not be appropriate for 'looped' playback mode,
        % but CWB has not encountered this specific situation yet and thus
        % has not dedicated much thought to it. 
        buffer_pos = 1; % start the buffer at beginning of the next stimulus
    end % if trial == 1 ...
        
    %% UPDATE TRIAL IN SANDBOX
    %   d.sandbox.trial is used by other functions
    d.sandbox.trial = trial; 
    
    %% EMPTY RECORDING
    rec=[]; 
    
    %% SELECT APPROPRIATE STIMULUS
    X=stim{trial};     
    
    % By file modcheck and data modification. 
    %   We check at the beginning of each "trial" and scale the upcoming
    %   sound appropriately. 
    if isequal(d.player.adaptive_mode, 'bytrial')
                
        % Call modcheck     
        %   Call modcheck at end of trial to keep referencing sensible. 
        for modifier_num=1:length(d.player.modifier)
    
            % Update variable in sandbox
            d.sandbox.modifier_num=modifier_num;
    
            % Initialize modifier
            [Y, d]=d.player.modifier{d.sandbox.modifier_num}.fhandle(X, mod_code, d); 
    
        end % for modifier_num                

    else
        % Assign X (raw data) to second variable for playback 
        Y=X; 
    end % isequal(d.player.adaptive_mode, 'bytrial')           
    
    % Switch to determine mode of adaptive playback. 
    switch lower(d.player.adaptive_mode)
        
        case {'continuous', 'bytrial'}             
                        
            % SETUP unmod DEVICE
            %   - Fill the buffer
            %   - Wait for an appropriate lead time (see
            %   'unmod_leadtime'). 
            if ~isempty(d.player.unmod_playbackmode)
                switch d.player.unmod_playbackmode
                    case {'looped'}
    
                        % If this is looped playback, then start the playback of the
                        % masker sound and let it run forever and ever. 
                        if trial == 1
                            PsychPortAudio('FillBuffer', shand, uX');                                                                                 
                            PsychPortAudio('Start', shand, 0, [], 0);
                        end % if trial == 1
                        
                    case {'stopafter'}
                        
                        % Fill the buffer once
                        if trial ==1
                            PsychPortAudio('FillBuffer', shand, uX');
                        end % 
                        
                        % Infinite loop playback
                        PsychPortAudio('Start', shand, 0, [], 0);
                        
                    otherwise
                        error('Unknown unmod_mode'); 
                end % switch/otherwise 
        
                % Crude wait time.                         
                WaitSecs(d.player.unmod_leadtime); 
                
                % Now wait 
                
            end % if ~isempty(d.player.unmod_playbackmode 
    
            %% CREATE WINDOWING FUNCTION (ramp on/off)
            %   This is used for continuous adaptive mode. The windowing function can
            %   be provided by the user, but it must be a function handle accepted
            %   by MATLAB's window function.    
            win=window(d.player.window_fhandle, round(d.player.window_dur*2*FS)); % Create onset/offset ramp

            % Match number of data_channels
            %   data_channels are ramped and mixed to match the number of
            %   physical_channels below. 
            win=win*ones(1, size(X,2)); 
    
            % Create ramp_on (for fading in) and ramp_off (for fading out)
            ramp_on=win(1:ceil(length(win)/2),:); ramp_on=[ramp_on; ones(block_nsamps - size(ramp_on,1), size(ramp_on,2))];
            ramp_off=win(ceil(length(win)/2):end,:); ramp_off=[ramp_off; zeros(block_nsamps - size(ramp_off,1), size(ramp_off,2))];    
            
            % nblocks            
            if isequal(d.player.playback_mode, 'looped')
                nblocks=inf;
            elseif isequal(d.player.playback_mode, 'standard')
                nblocks=ceil(size(X,1)./size(ramp_on,1)); 
            else
                error(['Unknown playback_mode: ' d.player.playback_mode]); 
            end % if
            
            % Store nblocks in sandbox. This is needed by some modcheck
            % functions for termination purposes (e.g.,
            % ANL_modcheck_keypress)
            d.sandbox.nblocks=nblocks; 
            
            % initiate block_num
            block_num=1;
            
            % Loop through each section of the playback loop. 
            while block_num <= nblocks

                rstatus=PsychPortAudio('GetStatus', rhand);
                
                % Start recording device
                %   Just start during the first trial. This will be emptied
                %   after every trial. Should not need to restart the recording
                %   device. 
                if d.player.record_mic && trial ==1 && isequal(d.player.state, 'run') && ~rstatus.Active

                    % Last input (1) tells PsychPortAudio to not move forward
                    % until the recording device has started. 
                    PsychPortAudio('Start', rhand, [], [], 1); 

                    % rec_start_time is the (approximate) start time of the recording. This is
                    % used to track the total recording time. 
                    rec_start_time=GetSecs;
                    rec_block_start=rec_start_time; 
                    
                end % if d.player.record_mic
                
%             for block_num=1:nblocks
%                 tic
                % Store block number in sandbox - necessary for some
                % termination procedures
                d.sandbox.block_num = block_num; 
                
                % Store buffer position
                d.sandbox.buffer_pos = buffer_pos; 
                
                % Which buffer block are we filling?
                %   Find start and end of the block
                startofblock=block_start(1+mod(block_num-1,2));
    
                % Load data using logical mask
                %   There is a special case when the logical mask is split
                %   - as in 110011. This occurs when the sound is not an
                %   even multiple of the block_dur setting (block_nsamps in
                %   main body of code). 
                %
                %   We want to do different things based on the playback
                %   mode. 
                %       'looped':           if this is true, then we want
                %                           to load the samples at the end
                %                           of the sound, then load the
                %                           samples at the beginning of the
                %                           sound (circular buffer type of
                %                           a deal).
                %
                %       'standard': just load the samples at the end of the
                %                   sound and zeropad the rest to fill the
                %                   buffer. 
                
                % If we don't have enough consecutive samples left to load
                % into buffer, then we need to do one of two things
                %
                %   1. Beginning loading sound from the beginning of the
                %   file again.
                %
                %   2. Load what we have and add zeros to make up the
                %   difference. 
                if buffer_pos + buffer_nsamps > size(Y,1)
                    
                    % Load data differently
                    if isequal(d.player.playback_mode, 'looped')
                        % If looped, then loop to load beginning of sound.
                        data=[Y(buffer_pos:end,:); Y(1:buffer_nsamps-(size(Y,1)-buffer_pos)-1,:)];
                    else
                        data=[Y(buffer_pos:end,:); zeros(buffer_nsamps-(size(Y,1)-buffer_pos)-1, size(Y,2))]; 
                    end % if d.player.looped_payback
                    
                else
                    data=Y(buffer_pos:buffer_pos+buffer_nsamps-1, :); 
                end % if any(dmask-1)
                
                % Modcheck and modifier for continuous playback
                if isequal(d.player.adaptive_mode, 'continuous')
                    
                    % Check if modification necessary
                    [mod_code, d]=d.player.modcheck.fhandle(d); 
                    
                    % Modify main data stream
                    %   Apply all modifiers. 
                    for modifier_num=1:length(d.player.modifier)
    
                        % Update variable in sandbox
                        d.sandbox.modifier_num=modifier_num;
    
                        % Call modifier
                        %   Only run premix modifiers
                        if isequal(d.player.modifier{d.sandbox.modifier_num}.mod_stage, 'premix')
                            [data, d]=d.player.modifier{d.sandbox.modifier_num}.fhandle(data, mod_code, d); 
                        end % if isequal
                            
                    end % for modifier_num
                                        
                end % if isequal ...       
                
                % Ramp new stream up, mix with old stream. 
                %   - The mixed signal is what's played back. 
                %   - We don't want to ramp the first block in, since the
                %   ramp is only intended to fade on block into the next in
                %   a clean way. 
                %   - 140523 CWB adds in an additional check. We want to
                %   fade sound in, even if it's the first block_num, if the
                %   buffer_position has been set to some other starting
                %   point. This way, if we start in the middle of a sound,
                %   we're less likely to encounter transients.
                if block_num==1 && buffer_pos==1
                    data2play=data(1:block_nsamps, :);
                elseif block_num==1 && buffer_pos~=1
                    data2play=data(1:block_nsamps, :).*ramp_on;
                else
                    % Fade out previous setting (x) and fade in the new
                    % data (first half of data). 
                    data2play=data(1:block_nsamps, :).*ramp_on + x.*ramp_off; 
                end % if block_num==1
                
                % Mix data into corresponding channels
                %   Each cell corresponds to a physical output channel.
                %   Each element with each cell corresponds to a column of
                %   data2play.
                data2play_mixed = data2play*d.player.mod_mixer;
                
                % Save second buffer block for fading on the next trial.
                %   Zero padding to make x play nicely when we're at the
                %   end of a sound                 
                x=[data(1+block_nsamps:end, :); zeros(block_nsamps-size(data(1+block_nsamps:end, :),1), size(data,2))]; 
                
                % Basic clipping check
                %   Kill any audio devices when this happens, then throw an
                %   error. 
                if max(max(abs(data2play_mixed))) > 1 && d.player.stop_if_error, 
                    warning('Signal clipped!'); 
                    d.player.state='exit'; 
                    break % exit and return variables to the user. 
                end % if max(max(abs(data))) > 1
                    
                % Post-mixing modifiers
                %   Some modifiers need to be run AFTER mixing. For
                %   instance, an inline digital filter to correct the
                %   frequency response and levels of audio drivers (e.g.,
                %   speakers) would need to be applied AFTER mixing.
                for modifier_num=1:length(d.player.modifier)

                    % Update variable in sandbox
                    d.sandbox.modifier_num=modifier_num;

                    % Call modifier
                    %   Only run premix modifiers
                    if isequal(d.player.modifier{d.sandbox.modifier_num}.mod_stage, 'postmix')
                        [data2play_mixed, d]=d.player.modifier{d.sandbox.modifier_num}.fhandle(data2play_mixed, mod_code, d); 
                    end % if isequal

                end % for modifier_num
                
                % Save playback data
                %   Data piped to the speakers are saved. This makes it
                %   easier for users to playback what was presented to each
                %   speaker at the commandline (using audioplayer or
                %   wavplay or some other variant). 
                d.sandbox.data2play_mixed=[d.sandbox.data2play_mixed; data2play_mixed]; 
                
                
                % Get playback device status
                pstatus=PsychPortAudio('GetStatus', phand);
                
                % First time through, we need to start playback
                %   This has to be done ahead of time since this defines
                %   the buffer size for the audio device.                 
                %
                %   Added additonal check so we only initialize the sound
                %   card ONCE. 
                %
                %   Added a 'run' state check. We don't want to start
                %   playback until the player is in the run state. 
                if block_num==1 && ~pstatus.Active && isequal(d.player.state, 'run')
                   
                    % Start audio playback, but do not advance until the device has really
                    % started. Should help compensate for intialization time. 
        
                    % Fill buffer with zeros
                    PsychPortAudio('FillBuffer', phand, zeros(buffer_nsamps, pstruct.NrOutputChannels)');
                    
                    % Add one extra repetition for a clean transition.
                    % Note that below we wait for the second buffer block
                    % before we fill the first, so we end up losing a
                    % single playthrough the buffer. This could be handled
                    % better, but CWB isn't sure how to do that (robustly)
                    % at the moment.
                    %
                    %   CWB changed so all playback modes have "infinite"
                    %   playback loops. This way the user can 'pause'
                    %   playback even in 'standard' playback_mode without
                    %   running out of playback cycles. The while loop now
                    %   controls the termination of playback rather than
                    %   the player itself.
%                     if nblocks==inf

                    PsychPortAudio('Start', phand, 0, [], 0);      
                    
                    playback_start_time = GetSecs; % Get approximate playback start time 
                    
%                     else
%                         PsychPortAudio('Start', phand, ceil( (nblocks)/2)+1, [], 0);                    
%                     end % if nblocks
                    
                    % Wait until we are in the second block of the buffer,
                    % then start rewriting the first. Helps with smooth
                    % starts 
                    pstatus=PsychPortAudio('GetStatus', phand); 
                    while mod(pstatus.ElapsedOutSamples, buffer_nsamps) - block_start(2) < refillat % start updating sooner.  
                        pstatus=PsychPortAudio('GetStatus', phand); 
                    end % while
                    
                end % if block_num==1               
    
                % Load data into playback buffer
                %   CWB tried specifying the start location (last parameter), but he
                %   encountered countless buffer underrun errors. Replacing the start
                %   location with [] forces the data to be "appended" to the end of the
                %   buffer. For whatever reason, this is far more robust and CWB
                %   encountered 0 buffer underrun errors.                 
                
                % Only try to fill the buffer if the player is in run state
                %   Perhaps this should be changed to monitor the
                %   pstatus.Active field?? Might lead to undetected errors
                %   ... 
                if pstatus.Active
                    PsychPortAudio('FillBuffer', phand, data2play_mixed', 1, []);  
%                 elseif isequal(d.player.state, 'pause') || isequal(d.player.state, 'exit')
%                     PsychPortAudio('FillBuffer', phand, zeros(size(data2play_mixed))', 1, []);                      
                end % if isequal ...                
                
                % Shift mask
                %   Only shift if the player is in the 'run' state.
                %   Otherwise, leave the mask as is. 
                %
                %   Note: This must be placed after the modcheck/modifier
                %   above (in continuous mode) or we run into a
                %   'stuttering' effect. This is due to the mask being
                %   improperly moved. 
                if isequal(d.player.state, 'run')
                    
                    % There are definitely "cooler" ways to do move the
                    % window of samples to load (CWB loves the idea of
                    % using a circularly shifted logical mask), but they
                    % were prohibitively slow. So, CWB had to go with a
                    % straightforward (and not so pretty) solution. 
                    buffer_pos=mod(buffer_pos+block_nsamps, size(Y,1)); 

                end % isequal(d.player.state, 'run'); 
                
%                 toc
                
                pstatus=PsychPortAudio('GetStatus', phand);

                % Now, loop until we're half way through the samples in 
                % this particular buffer block.
                while mod(pstatus.ElapsedOutSamples, buffer_nsamps) - startofblock < refillat ...                         
                        && isequal(d.player.state, 'run') % we don't want to loop and wait forever if the player isn't running. 
                    pstatus=PsychPortAudio('GetStatus', phand); 
                end % while
                
                % Error checking after each loop
                if d.player.stop_if_error && (pstatus.XRuns >0)
                    warning('Error during sound playback. Check buffer_dur.'); 
                    d.player.state='exit';
                    break 
                end % if d.player.stop ....
                
                % Zero out the second buffer block if we happen to end in
                % the first. 
                %   If this is not done, whatever was left in the second
                %   buffer block is played back again, which creates an
                %   artifact. 
                %
                %   Note: This probably shouldn't be applied in "looped
                %   playback" mode, but CWB needs to think about it more.
                %   XXX
%                 if block_num==nblocks && startofblock==block_start(1)
                if block_num==nblocks                      
                    PsychPortAudio('FillBuffer', phand, zeros(block_nsamps, size(X,2))', 1, []);  
                end % if block_num==nblocks
                
                % Empty recording buffer frequently
                %   Only empty if the recording device is active and the
                %   user wants us to gather recorded responses. 
                if d.player.record_mic && rstatus.Active
                    
                    % Check to make sure we are checking our buffer faster
                    % enough
                    if GetSecs - rec_block_start > d.player.record.buffer_dur
                        error('Recording buffer too short'); 
                    end 
                    
                    % empty buffer
                    trec=PsychPortAudio('GetAudioData', rhand)';
                    
                    % Empty recording buffer, if necessary. 
                    rec=[rec; trec]; 
                    
                    % Error check for clipping
                    if any(any(abs(trec)>=1)) && d.player.stop_if_error
                        warning('Recording clipped!');
                        d.player.state='exit';                        
                    end % 
                        
                    % Reset recording time
                    rec_block_start=GetSecs; 
                    
                end % d.player.record_mic
            
                % Only increment block information if the sound is still
                % being played. 
                if isequal(d.player.state, 'run')
                    
                    % Increment block count
                    block_num=block_num+1; 
                    
                end % if isequal ...
                
                % Clear mod_code
                %   Important if playback is paused for any reason. Do not
                %   want the mod_code applying to the same sound twice. 
                clear mod_code;
                
                % If player state is in 'exit', then stop all playback and
                % return variables
                if isequal(d.player.state, 'exit')
                    break; 
                end % 
            end % while
            
            % Grab the last known buffer position within our two-block
            % playback buffer.
%             pstatus=PsychPortAudio('GetStatus', phand);
%             end_pos = mod(pstatus.ElapsedOutSamples, buffer_nsamps) - startofblock; 
            end_block_pos = mod(pstatus.ElapsedOutSamples, buffer_nsamps) - block_start(block_start~=startofblock); % tells us where we were in the block the last time we checked
            end_OutSamples = pstatus.ElapsedOutSamples; % tells us how many samples total have played
            
            % Wait until we hit the first sample of what would be the next
            % block, then stop playback. This ensures all samples are
            % presented before soundplayback is terminated. 
            %   - CWB ran into issues with sounds being cut short with long
            %   block_dur(ations) (e.g., 0.4 s). This was not obvious with
            %   shorter block lengths.
            %             while mod(pstatus.ElapsedOutSamples, buffer_nsamps) - startofblock >= end_pos ...                         
            while buffer_nsamps - end_block_pos > pstatus.ElapsedOutSamples - end_OutSamples ...
                    && isequal(d.player.state, 'run') % we don't want to loop and wait forever if the player isn't running. 
                pstatus=PsychPortAudio('GetStatus', phand);             
            end % while
            
            % Schedule stop of playback device.
            %   Should wait for scheduled sound to complete playback. 
            if isequal(d.player.state, 'run')
                PsychPortAudio('Stop', phand, 1); 
            elseif isequal(d.player.state, 'exit')
                PsychPortAudio('Stop', phand, 0);                                
            end % if isequal ...
            
            % Stop unmodulated noise
            if isequal(d.player.unmod_playbackmode, 'stopafter')
                WaitSecs(d.player.unmod_lagtime);
                PsychPortAudio('Stop', shand, 0); 
            end % 
                        
            % Run the modcheck.
            if isequal(d.player.adaptive_mode, 'bytrial')
                
                % Call modcheck     
                [mod_code, d]=d.player.modcheck.fhandle(d);
                
            end % if isequal( ...          
            
            % Only empty recording buffer if user tells us to 
            if d.player.record_mic && rstatus.Active
            
                % Wait for a short time to compensate for differences in
                % relative start time of the recording and playback device.
                % After the wait, empty the buffer again. Now rec should
                % contain all of the signal + some delay at the beginning
                % that will need to be removed post-hoc in some sort of
                % sensible way. This is not a task for
                % portaudio_adaptiveplay. 
                WaitSecs(rec_start_time-playback_start_time);
                
                pstatus=PsychPortAudio('GetStatus', phand);
                rstatus=PsychPortAudio('GetStatus', rhand);
                
                % Check to make sure we are checking our buffer fast
                % enough                
                if GetSecs - rec_block_start > d.player.record.buffer_dur
                    error('Recording buffer too short'); 
                end % if GetSecs ...
            
                % Empty recording buffer, if necessary. 
                % empty buffer
                trec=PsychPortAudio('GetAudioData', rhand)';

                % Empty recording buffer, if necessary. 
                rec=[rec; trec]; 

                % Error check for clipping
                if any(any(abs(trec)>=1)) && d.player.stop_if_error
                    warning('Recording clipped!');
                    d.player.state='exit';                        
                end %                 

                % Save recording to sandbox
                d.sandbox.mic_recording{trial} = rec; 
                clear rec; % just to be safe, clear the variable
                
            end % if d.player.record_mic
            
            % Exit playback loop if the player is in exit state
            %   This break must be AFTER rec transfer to
            %   d.sandbox.mic_recording or the recordings do not
            %   transfer. 
            if isequal(d.player.state, 'exit');
                break
            end % isequal(d.player.state, 'exit'); 
        otherwise
            
            error(['Unknown adaptive mode (' d.player.adaptive_mode '). See ''''adaptive_mode''''.']); 
            
    end % switch d.player.adaptive_mode

end % for trial=1:length(X)

% Close all open audio devices
PsychPortAudio('Close');

% Attach end time
d.sandbox.end_time=now; 

% Attach stim variable
%   Decided not to do this since we already have the play list. But it
%   might be useful to kick back the data that are actually presented - so
%   we have a record of what was actually fed to the sound card after all
%   filtering, etc. is done. 
% d.sandbox.stim = stim; 

% Attach (modified) structure to results
%   This is returned to the user. 
results.RunTime = d; 