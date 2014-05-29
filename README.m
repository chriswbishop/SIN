=======================================================================================================
Test Setup -> What the user has to provide to get the player functions to work. Options structures can be tailored to each player. The example below configures the portaudio_adaptiveplay function to administer the HINT. 

	-> General settings (general): Generally static information across an experiment (e.g., subject ID motif, etc.)
		-> root: root directory for speech in noise (SIN) suite (required)		
		
	-> Test specific args (specific): parameters may vary, but some fields are required (e.g., testID). Example below is for the HINT. 
		-> testID: string with description test ID. (required)
		-> root: path to root directory where test specific materials are stored. 
		-> subjectID_regexp: regular expression describing subject ID motif. 
        -> list_filt (rename to list_regexp): regular expression to use in finding available list (for HINT, this is done by looking up available directories following the regexp 'List[0-9]{2}') (used by SIN_GUI)
		-> hint_lookup: information about lookup list containing word information, list IDs, etc.
            -> filename: full path to the file containing list information (used by importHINT)
			-> sheetnum: For Excel spreadsheets, we need to know which sheet to load - here, we load sheet two (2) (used by importHINT)            
				
	-> Player settings (player): Options used by the designated player (example for portaudio_adaptiveplay).
		
		-> player_handle: function handle to player (e.g., @portaudio_adaptiveplay) (required) This might be used by SIN_RunTest to administer tests by ID)
		
		-> Playback (Playback Parameters)			
			-> block_dur: buffer block duration in seconds
			-> device: playback device structure returned from portaudio_GetDevice
			-> fs: sampling rate
		
		-> Record (Recording parameters, if applicable)
			-> device: recording device
			-> fs: sampling rate
			-> buffer_dur: recording buffer duration (in sec)
		
        (Player Configuration)
		-> adaptive_mode:
        -> playback_mode: (looped | standard)
		-> append_files: 
        -> stop_if_error:
		-> playback_channels: XXX Removed and replaced with channel_mixer
		-> randomize: randomize playback list. This is currently handled in SIN_runTest, but I think it would be smarter to move this centralize playback features like this to the "player" (e.g., portaudio_adaptiveplay)
        -> startplaybackat: when to start playback within a sound. This parameter is useful when the user wants to start playback at an arbitrary point within a file. To start at the beginning of the file, set to 0. (no default)
        -> channel_mixer: 
        -> state: state of the player upon startup
        
		(Buffer Windowing)
		-> window_fhandle: windowing function handle
		-> window_dur: duration of windowing function in seconds
		
		(Unmodulated playback parameters : used to present constant noise on each trial or throughout playback
		-> unmod_playback: single element cell, full path to wav file
		-> unmod_channels: 
		-> unmod_playbackmode: 
		-> unmod_leadtime:
		-> unmod_lagtime: 
		
		(Modification Check: information will vary, example below for HINT_modcheck_GUI.m)
		-> modcheck
            -> fhandle: function handle
			-> playback_list: XXX this one could be a problem XXX XXX Not if we add the playback_list to the results structure and pass that around XXX
			-> scoring_method: 
			-> score_labels: 
		
		(Modifier): modifier information: setting will vary example below for modifier_dBscale)
		-> modifier
			-> dBstep: 
			-> change_step: 
			-> channels: 			
            
    -> Sandbox: a dirty area where variables can be stored if necessary and accessed by different functions (e.g., figure or axis information for plotting, etc).
    
    -> Calibration info (calibration): calibration information is provided here. This will mirror the "calibration" structure below exactly, whatever that ends up being.    
    
                
=======================================================================================================
Results Structure: Player return structure. This contains three basic fields
	-> User Options (UserOptions) (options provided by user, see Options structure above). This field can be used to relaunch the same test with the same settings (although playback order might change). 
	-> RunTime: modified (and appended) options structure. This may contain additional fields not present in User Options. The fields will vary by player type. Example below for portaudio_adaptiveplay. Only additional top-level fields are desribed below.
		-> playback_list: cell array of playback files
		-> voice_recording: cell array of recorded responses if the player is configured to record subject responses through the recording device (see Record field above). (should be added at end of playback, I think, to keep structure size down)

=======================================================================================================
Calibration info (specific): this is the output from the currently non-existent calibration routine that CWB needs to write. 
    -> root: root file for calibration. This is the directory that calibration files are located. SIN_HOME/calibration/YOUR_CALIBRATION/thecalfile
    -> output_root: where the next executed calibration will be stored, including the root file name. The filename will be appended with other information regarding physical_channel information and the like
    -> physical_channels: integer array, physical channels to calibrate
    -> calstimDir: the directory in which the calibration stimulus is located
    -> calstim_regexp: regular expression for selecting calibration stimulus from calstimDir
    -> reference:
        -> absoluteSPL: decibel level of calibration tone (e.g., 114 dB)
        -> rectime: (approximate) recording time for reference sound.     
    -> filter: settings needed to generate the frequency filter. The filter will (I think) be created by SIN_matchspectra
        -> resolution: the resolution of the filter (in Hz)
        -> XXX see SIN_matchspectra for other parameters that we'll need XXX
    -> instructions: a field with instruction information for various stages of the calibration process
        -> noise_estimation:   instructions during noise estimation. This is a recording with no (externally generated) sound input. No calibrator, no speakers being explicitly driven. This will serve as a baseline to which SNR can be estimated
        -> reference: instructions during reference recording
        -> playback: instructions to display during driver (e.g., speaker/earphone) calibration
        
    
    

    -> reference: contains information regarding the reference signal (e.g., calibrated tone)
        -> signal: reference recording (e.g., 1 kHz tone, 114 dB from 0.5 inch calibrator)
        -> absolute_SPL: the absolute level of the calibration signal (typically written on the side of the calibrator) (e.g., 114 dB)
    -> timeseries: contains information necessary to calibrate each physical_channel (soundcard output channel and/or speaker).
        -> physical_channels: integer array of channels that have a recording. These are the channels that are calibrated with the current calibration file.
        -> raw: cell array (?), each element has a recording from corresponding channel listed in 'physical_channels' above.
        -> processed: cell array of processed (XXX stupid name and too general to be helpful XXX)
    -> 