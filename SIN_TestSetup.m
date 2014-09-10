function opts=SIN_TestSetup(testID, subjectID)
%% DESCRIPTION:
%
%   Function to return test information. This will vary based on the test.
%   Alternatively, this can also return a list of available tests
%   (default).
%
% INPUT:
%
%   testID:     string, test identifer. Or, if the user wants to return a
%               list of available tests, leave testID empty.
%
% OUTPUT:
%
%   opts:       a test setup structure. Or, if testID is empty, a cell
%               array of available tests.
%
% Development:
%
%   1. Create case to return test list for GUI. 
%
% Christopher W. Bishop
%   University of Washington
%   5/14

if ~exist('testID', 'var') || isempty(testID), 
    testID='testlist'; 
end 

switch testID;
    
    case 'testlist'
        
        % Get cases within switch. Each case might be a test.
        %   Some of the cases are callback specific (e.g., generating the
        %   test list, an empty options structure, etc.). These are
        %   excluded based on the exclusion list (exlist) below. 
        tests = getCases(); 
        
        % Only list the following as fully function "tests". The cases that
        % are not listed are typically building blocks for these
        % higher-level calls. These are the tests that are typically listed
        % in the GUI. Other tests are meant only for "Advanced" users (not
        % students), so we won't list them at all. 
        %
        %   CWB changed this to an exclusion list instead. 
        tests2list={'Defaults' 'testlist'};
        
        % Assume we include everything by default
        mask=true(size(tests)); 
        
        for c=1:length(tests)
            if ~isempty(find(ismember(tests2list, tests{c}), 1, 'first'))
                mask(c)=false;
            end
        end % for c
                
        % Return test names 
        %   List tests vertically (easier to skim through)
        opts={tests{mask}}'; 
        
        % Return here so we don't try to assign a UUID.        
        return
        
    case 'Defaults'
               
        % Create an empty SIN testing structure
        opts = struct( ...
            'subject', struct(), ... % subject specific information, like subject ID, etc. 
            'general', struct(), ... % general information
            'specific', struct(), ... % test specific parameters (used by auxiliary functions like modchecks/modifiers/GUIs
            'player', struct(), ... % player configuration structure (e.g., for portaudio_adaptiveplay)
            'sandbox', struct());  % scratch pad for passing saved variables between different functions (e.g., data to plot, figure handles, etc.)        
        
        % Root SIN directory
        opts.general.root = fileparts(which('SIN_TestSetup.m'));  
        
        % Subject directory
        opts.general.subjectDir = fullfile(opts.general.root, 'subject_data'); 
        
        % Calibration information
        opts.general.noiseDir = fullfile(opts.general.root, 'playback', 'Noise'); 
        opts.general.noise_regexp = '.wav'; % get wav files
        
%         opts.general.calibrationDir = fullfile(opts.general.root, 'calibration');
%         opts.general.calibration_regexp = '.mat$'; % 
        
        % subject ID motif. Described using regexp. Used in
        % SIN_register_subject.m
        opts.general.subjectID_regexp='^[1 2][0-9]{3}$';
        
        % List of available tests
        %   This will vary by project. Field used to generate test list in
        %   SIN_GUI. CWB does not recall using it elsewhere. 
        opts.general.testlist = SIN_TestSetup('testlist'); 
        
        % Set subject information
        %   - Set subject identifier (subjectID)
        %   - Set subject-specific directory. This is different from the
        %   subjectDir found in the general field. 
        opts.subject.subjectID = subjectID; 
        opts.subject.subjectDir = fullfile(opts.general.subjectDir, opts.subject.subjectID); 
        
        % Set sound output paramters. 
        opts.player.playback = struct( ...
            'device', portaudio_GetDevice(12), ... % device structure, (20) for ASIO on Miller PC, 29 for fast track ASIO
            'block_dur', 1, ... % 200 ms block duration.
            'fs', 44100, ... % sampling rate            
            'internal_buffer', 4096); % used in 'buffersize' input to PsychPortAudio('Open', ...
        
        % Recording device
        opts.player.record = struct( ...
            'device', portaudio_GetDevice(12), ... % device structure. Use the MME recording device. Windows Sound introduces a lot of crackle in recording on CWB's machine.
            'buffer_dur', 120, ... recording buffer duration. Make this longer than you'll ever need for a single trial of HINT
            'fs', 44100); % recording sampling rate
        
        % Stop playback if we encounter an error
        opts.player.stop_if_error = true; 
        
        % Add player control modifiers
        %   Include a basic playback controller to handle "pauses",
        %   "resume", and "quit" requests.
        %   No, we don't want this added by default. Only to ANL
        opts.player.modifier={}; 
%         opts.player.modifier{1} = struct( ...
%             'fhandle', @modifier_PlaybackControl, ...
%             'mod_stage',    'premix');             
        
        % Where the UsedList is stored. 
        opts.specific.genPlaylist.UsedList = fullfile(opts.subject.subjectDir, [opts.subject.subjectID '-UsedList.mat']); % This is where used list information is stored.
        
        % Do not return the test as "to be used" test by default. There are
        % many cases that should not (typically) be called by the user. So,
        % don't return those.
        opts.specific.listtest = false; 
        
        % Preload stimuli by default
        %   Generally do not want to preload AV stims, though, so look for
        %   a change in MLST (AV). Also MLST (Audio)
        opts.player.preload = true;
        
        % Analysis defaults
        %   Empty analysis function handle and parameters. Set 'run' to
        %   false so SIN_runTest does not attempt to run an analysis by
        %   default. 
        opts.analysis = struct(...
            'fhand',    '', ...
            'run',  false, ...
            'params', struct()); 
        
        % Return so we do not assign a UUID to defaults. 
        return
        
    case 'PPT'
        
        % Perceived Performance Test (PPT) is a subjective measure of
        % performance on a HINT-style test. This should be otherwise
        % identical to 'HINT (SNR-50, keywords, 1up1down) algorithm.
        opts = SIN_TestSetup('HINT (SNR-50, keywords, 1up1down)', subjectID);
        
        % Change the test ID to PPT so the correct scoring scheme is used.
        opts.specific.testID = testID; 
        
        % Change scoring method to PPT based scoring
        opts.player.modcheck.scored_items = 'sentences';
        
        % Change scoring labels to something more intuitive
%         opts.player.modcheck.score_labels = {'C', 'Not_All'};

    case 'HINT (SNR-80, keywords, 4down1up)'
        
        % This will be very similar to HINT (SNR-50, keywords, 1up1down),
        % but will need to change the algorithm.
        opts=SIN_TestSetup('HINT (SNR-50, keywords, 1up1down)', subjectID); 
        
        % Change algorithm tracking
        %   Start with 1up1down, then switch to 4down1up after trial 4
        opts.player.modcheck.algo = {@algo_HINT1up1down @algo_HINT4down1up}; 
        opts.player.modcheck.startalgoat=[1 5]; 
        
    case 'HINT (SNR-50, keywords, 1up1down)'
        
        % ============================
        % Get default information
        % ============================
        opts=SIN_TestSetup('Defaults', subjectID); 
        
        % ============================
        % Test specific information. These arguments are used by
        % test-specific auxiliary functions, like importHINT and the like. 
        % ============================
        
        % set the testID (required)
        opts.specific.testID = testID;
        
        % root directory for HINT stimuli and lookup list
        opts.specific.root=fullfile(opts.general.root, 'playback', 'HINT');        
        
        % set a regular expression to find available lists within the HINT
        % root directory.
        %   Look for all directories beginning with "List" and ending in
        %   two digits. 
        opts.specific.list_regexp='List[0-9]{2}'; 
                
        % Set regular expression for wav files
        opts.specific.wav_regexp = '[0-9]{2};0dB[+]spshn.wav$'; % Use calibrated noise files (calibrated to 0 dB)
        
        % full path to HINT lookup list. Currently an XLSX file provided by
        % Wu. Used by importHINT.m
        opts.specific.hint_lookup=struct(...
            'filename', fullfile(opts.specific.root, 'HINT (;0dB+spshn).xlsx'), ...
            'sheetnum', 1); 
        
        % The following set of subfields are required for playlist
        % generation. They are used in a call to SIN_getPlaylist, which in
        % turn invokes SIN_stiminfo and other supportive functions.         
        opts.specific.genPlaylist.NLists = 2; % The number of lists to include in the playlist. Most lists have a fixed number of stimuli, so multiply by that number to get the total number of stims.
        opts.specific.genPlaylist.Randomize = 'lists&within'; % randomize list order and stimuli within each list.
        opts.specific.genPlaylist.Repeats = 'allbefore'; % All lists must be used before we repeat any.         
        opts.specific.genPlaylist.Append2UsedList = true; % append list to UsedList file. We might need to create an option to remove the items from the list if an error occurs
        
        % ============================
        % Player configuration
        %   The fields below are used by the designated player to configure
        %   playback.
        %
        %   - Note: some of these are set in 'Project AD' above
        % ============================
        
        % Function handle for designated player
        opts.player.player_handle = @portaudio_adaptiveplay; 
        
        opts.player = varargin2struct( ...
            opts.player, ...
            'adaptive_mode',    'bytrial', ... % 'bytrial' means modchecks performed after each trial.
            'record_mic',       true, ...   % record playback and vocal responses via recording device. 
            'randomize',        false, ...   % randomize trial order before playback
            'append_files',     false, ...  % append files before playback (makes one long trial)
            'window_fhandle',   @hann, ...  % windowing function handle (see 'window.m' for more options)
            'window_dur',       0.005, ...  % window duration in seconds.
            'playback_mode',    'standard', ... % play each file once and only once 
            'playertype',       'ptb (standard)', ... % use standard PTB playback. Streaming can introduce issues.  
            'startplaybackat',    0, ...  % start playback at beginning of files
            'mod_mixer',    fillPlaybackMixer(opts.player.playback.device, [ [db2amp(-10); 0] [0; 1] ], 0), ... % play HINT target speech to first channel, spshnoise to second channel. Start with -10 dB SNR
            'contnoise',    [], ... % no continuous noise to play (for this example) 
            'state',    'run'); % Start in run state
            
        % ============================
        % Modification check (modcheck) configuration        
        % ============================
        opts.player.modcheck=struct(...
            'fhandle',         @modcheck_HINT_GUI, ...
            'data_channels',    1, ...
            'physical_channels', 1, ...
            'scored_items',  'keywords', ... % score only keywords (excludes articles?)
            'algo',     {{@algo_HINT1up1down}}, ... % use a one-up-one-down algo
            'startalgoat',     [1], ... % start algorithms at trials 1/5
            'score_labels',   {{'Correct', 'Incorrect'}}); % scoring labels for GUI
        
        % ============================
        % Modifier configuration        
        % ============================
        
        % Modifier to scale mixing information
        opts.player.modifier{end+1} = struct( ...
            'fhandle',  @modifier_dBscale_mixer, ... % use a decibel scale, apply to mod_mixer setting of player
            'mod_stage',    'premix',  ...  % apply modifications prior to mixing
            'dBstep',   [4 2], ...  % use variable step size. This matches HINT as normally administered
            'change_step', [1 5], ...   % This matches HINT as normally administered. 
            'data_channels', 1, ... % HINT speech coming out of data channel 1 (now) 
            'physical_channels', 1);  % apply decibel step to discourse stream in first output channel 
        
        % Modifier to track mod_mixer settings
        opts.player.modifier{end+1} = struct( ...
            'fhandle',  @modifier_trackMixer, ...
            'mod_stage',    'premix');   % track mod_mixer        
        
        % ============================
        % Analysis        
        % ============================
        opts.analysis = struct( ...
            'fhand',    @analysis_HINT, ...  % functioin handle to analysis function
            'run',  true, ... % bool, if set, analysis is run from SIN_runTest after test is complete.
            'params',   struct(...  % parameter list for analysis function (analysis_HINT)
                'tmask',    fillPlaybackMixer(opts.player.playback.device, [1;0], 0), ...   % just get data/physical channel 1                
                'RTSest',   'traditional',  ... % use traditional RTS estimation (average over trials 5:N+1
                'plot', true)); % generate plot
    case 'ANL'
        % ANL is actually a sequence of tests. The list includes the
        % following:
        %
        %   1. ANL (MCL-Too Loud)
        %   2. ANL (MCL-Too Quiet)
        %   3. ANL (MCL-Estimate)
        %   4. ANL (BNL-Too Loud)
        %   5. ANL (BNL-Too Quiet)
        %   6. ANL (BNL-Estimate)
        %
        % These parameters serve as the base settings and tests to run, but
        % additional steps must be taken to copy parameters over from one
        % test sequence to the next (e.g., the buffer position and overall
        % sound levels, according to modifier_dBscale). Also need to copy
        % over calibration information from one test to the next.        
        opts(1)=SIN_TestSetup('ANL (MCL-Too Loud)', subjectID); 
        opts(2)=SIN_TestSetup('ANL (MCL-Too Quiet)', subjectID); 
        opts(3)=SIN_TestSetup('ANL (MCL-Estimate)', subjectID); 
        opts(4)=SIN_TestSetup('ANL (BNL-Too Loud)', subjectID); 
        opts(5)=SIN_TestSetup('ANL (BNL-Too Quiet)', subjectID); 
        opts(6)=SIN_TestSetup('ANL (BNL-Estimate)', subjectID); 
        
    case 'ANL (MCL-Too Loud)'
        % ANL (MCL-Too Loud) is the first step in the ANL sequence. The
        % listener is instructed to adjust the speech track until it is too
        % loud. 
        
        % Get base
        opts=SIN_TestSetup('ANL (base)', subjectID); 
        
        % Change testID
        opts.specific.testID = testID;
        
        % Change instructions
        opts.player.modcheck.instructions={...
            'You will listen to a story through the loudspeaker. These hand held buttons will allow you to make adjustments (Show the subject the buttons). When you want to turn the volume up - push this button (point to the up button), and when you want to turn the volume down - push this button (point to the down button). I will instruct you throughout the experiment. ' ...
            'Now I will turn the story on. Using the up button, turn the level of the story up until it is too loud (i.e., louder than most comfortable). Each time you push the up button, I will turn the story up.' };
        
        % Set mixer
        opts.player.mod_mixer=fillPlaybackMixer(opts.player.playback.device, [ [db2amp(-15); 0 ] [0; 0]], 0); % just discourse in first channel 
        
    case 'ANL (MCL-Too Quiet)'
        
        % This is just like the ANL (base), but with different
        % instructions and a different starting buffer position.
        opts=SIN_TestSetup('ANL (base)', subjectID); 
        
        % Change testID
        opts.specific.testID = testID; 
        
        % Change instructions
        opts.player.modcheck.instructions={...
            'Good. Using the down button, turn the level of the story down until it is too soft (i.e., softer than most comfortable). Each time you push the down button, I will turn the story down (use 5 dB steps)'};
        
        % Set mixer
        opts.player.mod_mixer=fillPlaybackMixer(opts.player.playback.device, [ [0.5; 0] [0; 0 ] ], 0); % just discourse in first channel 
        
    case 'ANL (MCL-Estimate)' 
        
        opts=SIN_TestSetup('ANL (base)', subjectID); 
        
        % Change testID
        opts.specific.testID=testID; 
        
        % Change instructions
        opts.player.modcheck.instructions={...
            'Good. Now turn the level of the story back up to until the story is at your most comfortable listening level (i.e., or your prefect listening level) (use 2 dB steps).'};           
        
        % Change step size to 2 dB
        %   First, find the dBscale mixer modifier
        ind = getMatchingStruct(opts.player.modifier, 'fhandle', @modifier_dBscale_mixer);
        opts.player.modifier{ind}.dBstep = 2; 
        clear ind; 
        
        % Set mixer
        opts.player.mod_mixer=fillPlaybackMixer(opts.player.playback.device, [ [0.5; 0] [0; 0 ] ], 0); % just discourse in first channel 
        
    case 'ANL (BNL-Too Loud)'
        
        opts=SIN_TestSetup('ANL (base)', subjectID); 
        
        % Change testID
        opts.specific.testID=testID; 
        
        % Change instructions
        opts.player.modcheck.instructions={...
            'Now I�m going to leave the level of the story at this level (i.e., MCL) and turn on some background noise. Your up/down buttons will adjust the level of the background noise. Using the up button, turn the level of background noise up until you can�t hear the story. Each time you push the up button, I will turn the background noise up (use 5 dB steps).'};           
        
        opts.player.modifier{2}.data_channels=2; 
        
        % Set mixer
        opts.player.mod_mixer=fillPlaybackMixer(opts.player.playback.device, [ [0; db2amp(-15)] [0; 0 ] ], 0); % discourse channel and babble to first channel only
        
    case 'ANL (BNL-Too Quiet)' 
        
        opts=SIN_TestSetup('ANL (base)', subjectID); 
        
        % Change testID
        opts.specific.testID=testID; 
        
        % Change instructions
        opts.player.modcheck.instructions={...
            'Good. Using the down button, turn the level of the background noise down until the story is very clear (i.e., you can follow the story easily). Each time you push the down button, I will turn the level of the background noise down (use 5 dB steps).'};           
        
        opts.player.modifier{2}.data_channels=2; 
        
        % Set mixer
        opts.player.mod_mixer=fillPlaybackMixer(opts.player.playback.device, [ [0.5; 0.5] [0; 0 ] ], 0); % discourse channel and babble to first channel only       
    
    case 'MLST (AV, Unaided, SSN, 65 dB SPL, +8 dB SNR)'
        
        % Start with the AV aided condition. same test, different subject
        % state. 
        opts = SIN_TestSetup('MLST (AV, Aided, SSN, 65 dB SPL, +8 dB SNR)', subjectID); 
        opts.specific.testID = testID;         
                
    case 'MLST (AV, Aided, SSN, 65 dB SPL, +8 dB SNR)'
        
        % Start with the audio condition
        opts = SIN_TestSetup('MLST (Audio, Aided, SSN, 65 dB SPL, +8 dB SNR)', subjectID); 
        opts.specific.testID = testID; 
        
        % Change wav_regexp to pull in MP4s
        opts.specific.wav_regexp = '[0-9]{1,2}_T[0-9]{1,2}_[0-9]{3}_[HL][DS];0dB.mp4$';    
        
    case 'MLST (Audio, Unaided, SSN, 65 dB SPL, +8 dB SNR)'
        
        % Same test, different subject state
        opts = SIN_TestSetup('MLST (Audio, Aided, SSN, 65 dB SPL, +8 dB SNR)', subjectID); 
        
        opts.specific.testID = testID;     
        
    case 'MLST (Audio, Aided, SSN, 65 dB SPL, +8 dB SNR)'
        
        % Configured to administer the (audio only) MLST. Different
        % parameters required for the audiovisual version
        
        % Use the HINT as a starting point
        %   - The HINT is quite similar to the MLST in many ways, so let's
        %   use this as a starting point. 
        opts = SIN_TestSetup('HINT (SNR-50, keywords, 1up1down)', subjectID); 
        
        % Change the test ID
        opts.specific.testID = testID;
        
        % Change root directory
        opts.specific.root=fullfile(opts.general.root, 'playback', 'MLST (Adult)');
        
        % Change the wav_regexp
        %   We are using MP3 format here.
        warning('We might need to use MP4s instead of MP3s if we alter the timing and rewrite files for AV playback'); 
        opts.specific.wav_regexp = '[0-9]{1,2}_T[0-9]{1,2}_[0-9]{3}_[HL][DS];0dB.wav$'; 
        
        % Change list_regexp
        %   MLST has an underscore in list directories.
        opts.specific.list_regexp='List_[0-9]{2}'; 
        
        % Change sentence lookup information
        %   This is used for scoring purposes
        opts.specific.hint_lookup.filename=fullfile(opts.specific.root, 'MLST (Adult);0dB.xlsx');
        opts.specific.hint_lookup.sheetnum=1;   
        
        % Change mod_mixer to work with single channel data
        %   Scale speech track to full volume, assuming we calibrate to 65
        %   dB SPL. 
        opts.player.mod_mixer = fillPlaybackMixer(opts.player.playback.device, [1 0], 0);
        
        % Remove the modifier_dbBscale_mixer
        ind = getMatchingStruct(opts.player.modifier, 'fhandle', @modifier_dBscale_mixer);
        mask = 1:length(opts.player.modifier);
        mask = mask~=ind;
        opts.player.modifier = {opts.player.modifier{mask}}; 
        
        % For plotting purposes, track the first channel
        opts.player.modcheck.data_channels = 1; 
        
        % We aren't applying any changes. Just using the GUI for scoring. 
        opts.player.modcheck.algo = {@algo_HINTnochange}; %
        
        % Use keyword scoring only
        %   Keywords are denoted as capital letters. 
        opts.player.modcheck.scored_items = 'keywords'; 
        
        %% SETUP TO USE WITH WINDOWS MEDIA PLAYER
        % Set PlayerType to WMP (Windows Media Player)
        opts.player.playertype = 'WMP'; % used by portaudio_adaptiveplay to use windows media player (WMP)
        opts.player.activex = 'WMPlayer.OCX.7'; % name of ActiveX controller for WMP. see info = actxcontrollist; to find specifics on your system.
        opts.player.screennum = 0;     % screen to use for visual playback
        opts.player.screenposition = [0 0]; % set screen position
        tmp = Screen('Resolution', opts.player.screennum);
        
        opts.player.screensize = [tmp.width tmp.height]; 
        clear tmp; % clear out screen information
        
        opts.player.WMPvol = 100; % windows media player volume
        
        % This way the player doesn't waste time loading the files into a
        % matrix - we won't need these data in MATLAB since WMP will be
        % handling playback. 
        opts.player.preload = false; 
        
        %% CONTINUOUS NOISE INFORMATION
        opts.player.contnoise = fullfile(opts.general.root, 'playback', 'Noise', 'MLST-Noise(cropped);0dB.wav'); % File name
        opts.player.noise_mixer = fillPlaybackMixer(opts.player.playback.device, [db2amp(-8) 0], 0); % reduce noise levels to reach -8 dB SNR     
        
    case 'ANL (BNL-Estimate)'
        
        opts=SIN_TestSetup('ANL (base)', subjectID); 
        
        % Change testID
        opts.specific.testID=testID; 
        
        % Change instructions
        opts.player.modcheck.instructions={...
            'Good. Now turn the level of the background noise back up to the MOST noise that you would be willing to put-up-with and still follow the story for a long period of time without becoming tense or tired.'};           
        
        % Change step size to 2 dB
        %   First, find the dBscale mixer modifier
        ind = getMatchingStruct(opts.player.modifier, 'fhandle', @modifier_dBscale_mixer);
        opts.player.modifier{ind}.dBstep = 2; 
        opts.player.modifier{ind}.data_channels=2; 
        clear ind; 
        
        % Set mixer
        opts.player.mod_mixer=fillPlaybackMixer(opts.player.playback.device, [ [0.5; 0.5] [0; 0 ] ], 0); % discourse channel and babble to first channel only        
    
    case 'ANL (base)' % base settings for sequence of tests comprising ANL
        % ANL is administered differently than HINT or PPT. Here's a
        % very basic breakdown of the procedure.
        %
        %   Stage 1: Establishing the most comfortable level (MCL)
        %
        %       1. Start story at 30 dB HL. 
        %       2. Subject adjusts speech until it is uncomfortable (5
        %       dB steps)
        %       3. Subject adjust speech until it is too quiet (5 dB
        %       steps)
        %       4. Turn story back up until it is at "[the subject's] most
        %       comfortable listeneing level". (2 dB steps)
        %           - Note: OK to decrease too, if necessary. 
        %       5. Record the speech level. This is MCL 
        %
        %   Stage 2: Establishing the background noise level (BNL)
        %
        %       1. Add in background noise (30 dB HL). 
        %       2. Listener raises noise level until he/she can no
        %       longer hear the story (5 dB steps)
        %       3. Listener lowers the noise level until he/she can
        %       understand the story easily. (5 dB steps)
        %       4. Listener adjusts background noise to the MOST noise
        %       that he would be willing to tolerate and still follow
        %       the story for a long period of time without becoming
        %       tense or tired. 
        %       5. Record noise level. This is BNL. 
        %
        %   Stage 3: Acceptable Noise Level (ANL) Calculation
        %
        %       1. MCL (stage 1) - BNL;
         
        % Test setup for the Acceptable Noise Level (ANL) Test
        % ============================
        % Get default information
        % ============================
        opts=SIN_TestSetup('Defaults', subjectID);
        
        % ============================
        % Test specific information. These arguments are used by
        % test-specific auxiliary functions, like importHINT and the like. 
        % ============================
        
        % set the testID (required)
        opts.specific.testID=testID;
        
        % root directory for HINT stimuli and lookup list
        opts.specific.root=fullfile(opts.general.root, 'playback', 'ANL');
              
        % Regular expression used to grab available list of ANL files
        %   Traditionally, there's only one file with a male talker in one
        %   channel and a multi-talker stream in a second channel. These
        %   are controlled independently, but often routed to the same
        %   speaker. 
        %   
        %   This field is used in SIN_stiminfo.m. 
        opts.specific.wav_regexp='ANL;0dB.wav'; 
        
        % The following set of subfields are required for playlist
        % generation. They are used in a call to SIN_getPlaylist, which in
        % turn invokes SIN_stiminfo and other supportive functions.         
        opts.specific.genPlaylist.NLists = 0; % No lists to choose from
        opts.specific.genPlaylist.Randomize = ''; % No stimuli to randomize
        opts.specific.genPlaylist.Repeats = ''; % irrelevant since there aren't any lists        
        opts.specific.genPlaylist.Append2UsedList = true; % don't append the generated lists to the USedList file by default. We'll want SIN_runTest to handle this and only do so if the test exits successfully. 
        
        % ============================
        % Playback configuration
        %
        %   CWB running into issues with playback buffer size. Needs to be
        %   longer for longer files (due to indexing overhead)
        %
        % ============================
        
        % ============================
        % Player configuration
        %   The fields below are used by the designated player to configure
        %   playback.
        %
        %   - Note: some of these are set in 'Project AD' above
        % ============================
        
        % Function handle for designated player
        opts.player.player_handle = @portaudio_adaptiveplay; 
        
        warning('Mixing weights are set to 0.5. Need to make sure this is what CWB wants'); 
        
        opts.player = varargin2struct( ...
            opts.player, ...
            'adaptive_mode',    'continuous', ... % 'continuous' adaptive playback
            'record_mic',       true, ...   % record playback and vocal responses via recording device. 
            'randomize',        false, ...   % randomize trial order before playback
            'append_files',     true, ...  % append files before playback (makes one long trial)
            'window_fhandle',   @hann, ...  % windowing function handle (see 'window.m' for more options)
            'window_dur',       0.005, ...  % window duration in seconds.
            'playback_mode',    'looped', ... % loop sound playback - so the same sound just keeps playing over and over again until the player exits
            'playertype',       'ptb (stream)', ... % use streaming playback mode 
            'startplaybackat',    0, ...  % start playback at beginning of sound 
            'mod_mixer',    fillPlaybackMixer(opts.player.playback.device, [ [1;1] [0;0] ], 0), ... % Play both channels to left ear only. 
            'state',    'pause'); % start in paused state
        
        % ============================
        % Modification check (modcheck) configuration        
        % ============================
        opts.player.modcheck=struct(...
            'fhandle',  @ANL_modcheck_keypress, ...     % check for specific key presses
            'instructions', {{'You will listen to a story through the loudspeaker. These hand held buttons will allow you to make adjustments (Show the subject the buttons). When you want to turn the volume up - push this button (point to the up button), and when you want to turn the volume down - push this button (point to the down button). I will instruct you throughout the experiment.'}}, ...
            'keys',     [KbName('i') KbName('j') KbName('p') KbName('q') KbName('r')], ...  % first key makes sounds louder, second makes sounds quieter, third for pause, fourth for quit, fifth for run             
            'map',      zeros(256,1), ...
            'title', 'Acceptable Noise Level (ANL)');
%             'fhandle', @modcheck_ANLGUI, ...
         
        
        % Assign keys in map
        opts.player.modcheck.map(opts.player.modcheck.keys)=1; 
        
        % ============================
        % Modifier configuration                
        % ============================
        % Add the modifier for playback control
        %   Needed to start/stop/pause playback during testing 
        opts.player.modifier{end+1} = struct( ...
            'fhandle', @modifier_PlaybackControl, ...
            'mod_stage',    'premix');  % Apply during premixing phase. 
            
        % Modifier to scale mixing information
        opts.player.modifier{end+1} = struct( ...
            'fhandle',  @modifier_dBscale_mixer, ... % use a decibel scale, apply to mod_mixer setting of player
            'mod_stage',    'premix', ... % run modification prior to mixing. 
            'dBstep',   5, ...  % use constant 1 dB steps
            'change_step', 1, ...   % always 1 dB
            'data_channels', 1, ...
            'physical_channels', 1);  % apply decibel step to discourse stream in first output channel 
        
        % Modifier to track mod_mixer settings. Used by other functions for
        % plotting purposes. Note that modifier_trackMixer should always be
        % at the END of the modifier list, since other modifiers might also
        % modify the mixing matrix. 
        opts.player.modifier{end+1} = struct( ...
            'fhandle',  @modifier_trackMixer, ...
            'mod_stage',    'premix');   % track mod_mixer   
        
        % ============================
        % Analysis Configuration               
        % ============================
        opts.analysis = struct( ...
            'fhand',    @analysis_ANL, ...  % functioin handle to analysis function
            'run',  true, ... % bool, if set, analysis is run from SIN_runTest after test is complete.
            'params',   struct(...  % parameter list for analysis function (analysis_ANL)
                'order',    1:6, ...
                'tmask',    logical(fillPlaybackMixer(opts.player.playback.device, [1;0], 0)), ...   % just get data/physical channel 1
                'nmask',    logical(fillPlaybackMixer(opts.player.playback.device, [0;1], 0)), ...   % get data chan 2/phys chan 1
                'plot', true)); % generate plot
            
    case 'Hagerman'
        
        %% SETUP FOR HAGERMAN STYLE RECORDINGS
        %   This specific experiment has some basic needs. 
        %       - Play back and record a specific set of files in
        %       randomized order. 
        %       - Create some plots/summary statistics after run time. 
        %   That's it! Let's see how quickly that can be done ...
        % ============================
        % Get default information
        % ============================
        opts=SIN_TestSetup('Defaults', subjectID); 
        
        % ============================
        % Test specific information. These arguments are used by
        % test-specific auxiliary functions, like importHINT and the like. 
        % ============================
        
        % set the testID (required)
        opts.specific.testID = testID;
        
        % root directory for HINT stimuli and lookup list
        opts.specific.root=fullfile(opts.general.root, 'playback', 'Hagerman');        
        
        % set a regular expression to find available lists within the HINT
        % root directory.
        %   Look for all directories beginning with "List" and ending in
        %   two digits. 
        opts.specific.list_regexp=''; 
                
        % Set regular expression for wav files
        opts.specific.wav_regexp = '.wav$'; % Use calibrated noise files (calibrated to 0 dB)
        
        % full path to HINT lookup list. Currently an XLSX file provided by
        % Wu. Used by importHINT.m
                
        % The following set of subfields are required for playlist
        % generation. They are used in a call to SIN_getPlaylist, which in
        % turn invokes SIN_stiminfo and other supportive functions.         
        opts.specific.genPlaylist.NLists = 0; % The number of lists to include in the playlist. Most lists have a fixed number of stimuli, so multiply by that number to get the total number of stims.
        opts.specific.genPlaylist.Randomize = ''; % randomize list order and stimuli within each list.
        opts.specific.genPlaylist.Repeats = ''; % All lists must be used before we repeat any.         
        opts.specific.genPlaylist.Append2UsedList = false; % Theres not really anything here to track, so don't worry about adding it to the used stimulus list. 
        
        % ============================
        % Player configuration
        %   The fields below are used by the designated player to configure
        %   playback.
        %
        %   - Note: some of these are set in 'Project AD' above
        % ============================
        
        % Function handle for designated player
        opts.player.player_handle = @portaudio_adaptiveplay; 
        
        opts.player = varargin2struct( ...
            opts.player, ...
            'adaptive_mode',    'none', ... % 'bytrial' means modchecks performed after each trial.
            'record_mic',       true, ...   % record playback and vocal responses via recording device. 
            'randomize',        false, ...   % randomize trial order before playback
            'append_files',     false, ...  % append files before playback (makes one long trial)
            'window_fhandle',   @hann, ...  % windowing function handle (see 'window.m' for more options)
            'window_dur',       0.005, ...  % window duration in seconds.
            'playback_mode',    'standard', ... % play each file once and only once 
            'playertype',       'ptb (standard)', ... % use standard PTB playback. Streaming can introduce issues.                          '
            'mod_mixer',    fillPlaybackMixer(opts.player.playback.device, [ [1; 0] [0; 1] ], 0), ... % play stimuli at full amplitude. They are already scaled in the files. 
            'startplaybackat',    0, ...  % start playback at beginning of files
            'contnoise',    [], ... % no continuous noise to play (for this example) 
            'state',    'run'); % Start in run state
            
        % ============================
        % Modification check (modcheck) configuration        
        % ============================
        opts.player.modcheck=struct(); % Empty modcheck (don't need one here)
        
        % ============================
        % Modifier configuration        
        % ============================
        %   No modifiers for playback
        % Modifier to scale mixing information
        opts.player.modifier{end+1} = struct();  % No modifier necessary
        
        % ============================
        % Analysis        
        % ============================
        opts.analysis = struct( ...
            'fhand',    @analysis_HINT, ...  % functioin handle to analysis function
            'run',  false, ... % bool, if set, analysis is run from SIN_runTest after test is complete.
            'params',   struct(...  % parameter list for analysis function (analysis_HINT)
                'tmask',    fillPlaybackMixer(opts.player.playback.device, [1;0], 0), ...   % just get data/physical channel 1                
                'RTSest',   'traditional',  ... % use traditional RTS estimation (average over trials 5:N+1
                'plot', true)); % generate plot
            
    otherwise
        
        error('unknown testID')
        
end % switch 

%% ADD UUID TO STRUCTURE
%   - Assigns (or overwrites) a UUID.
opts = SIN_assignUUID(opts); 

%% WHERE TO SAVE DATA??
%   Save all data in the top-level directory for each subject. Originally
%   CWB had all testing materials in a separate folder for each test
%   (subfolders for each subject), but with the addition of a UUID, this
%   became unnecessary. 
%
%   File output takes the format of 
%     UUID;subject ID; test ID
%
%   CWB decided to list the UUID first so multipart tests list together in
%   the browser (easier to spot by eye). 
%
%   For multi-part tests, use the same UUID and the same saveData2mat file.
%
%   CWB decided that the format described above was WAY too confusing to
%   look at, so went back to original format. 
for i=1:length(opts)
    opts(i).specific.saveData2mat = fullfile(opts(1).subject.subjectDir, [opts(1).subject.subjectID '-' testID ' (' opts(1).specific.uuid ')']);
end %

end % function end