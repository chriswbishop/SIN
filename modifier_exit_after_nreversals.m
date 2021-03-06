function [Y, d]=modifier_exit_after_nreversals(X, mod_code, varargin)
%% DESCRIPTION:
%
%   This function will set the player state to 'exit' after a specific
%   number of reversals are encountered in a specific data/physical channel
%   combination. This *must* be paired with modifier_trackMixer in order to
%   work since it relies on the subfield created by _trackMixer to compute
%   the number of reversals.
%
% INPUT:
%
%   X:  original audio stream (unmodified in this section)
%
% Parameters:
%
%   These fields must be defined in the modifier structure of the grander
%   options structure (e.g., opts.player.modifier{XXX}.data_channels ...)
%
%   'data_channels':    the data channel to look at in mod_mixer. This
%                       corresponds to the row of the matrix.
%
%   'physical_channels':    the physical channel to look at in mod_mixer.
%                           This corresponds to the column of the matrix.
%
%   'max_revs': integer, number of reversals. When the number of reversals
%               reaches nrev, the function will set the player state to
%               'exit'. 
%
%   'start_trial':  integer, the trial at which we start tracking the
%                   number of reversals. This proved to be a useful option
%                   for HINT (SNR-80 ...) during which the first few trials
%                   follow a 1up1down algo and the remaining trials follow
%                   a 3down1up. We only wanted to count the reversals AFTER
%                   the 3down1up begin. 
%
% OUTPUT:
%
%   Y:  unmodified audio stream.
%
%   d:  modified options structure with potentially updated player state
%
% Development:
%
%   None (yet)
%
% Christopher W Bishop
%   University of Washington
%   10/14

%% GET PARAMETERS
d=varargin2struct(varargin{:}); 

% The player is made to work with a "SIN" style structure. If the user has
% defined inputs just at the commandline, then reassign to make it
% compatible.
if ~isfield(d, 'player')
    d.player = d; 
end % if

%% GET IMPORTANT VARIABLES FROM SANDBOX
modifier_num=d.sandbox.modifier_num; 
trial = d.sandbox.trial; 

%% GET MODIFIER PARAMETERS
data_channels = d.player.modifier{modifier_num}.data_channels; 
physical_channels = d.player.modifier{modifier_num}.physical_channels; 
max_revs = d.player.modifier{modifier_num}.max_revs; 
start_trial = d.player.modifier{modifier_num}.start_trial; 

if ~isfield(d.player.modifier{modifier_num}, 'initialized') || isempty(d.player.modifier{modifier_num}.initialized), d.player.modifier{modifier_num}.initialized=false; end

%% ASSIGN RETURN DATA
%   This function does not alter the data directly, so just spit back the
%   original data
Y=X; 

%% IF THIS IS OUR FIRST CALL, JUST INITIALIZE 
%   - No modifications necessary, just return the data structures and
%   original time series.
if ~d.player.modifier{modifier_num}.initialized
    
    % Set the initialization flag
    d.player.modifier{modifier_num}.initialized=true;
    
    return
    
end % if ~d.player.modifier{modifier_num}.initialized

%% GET THE DATA TRACE
%   We only want to track reversals and all that jazz after we have reached
%   the start_trial
if trial >= start_trial
    data = db(squeeze(d.sandbox.mod_mixer(data_channels, physical_channels, :)));

    %% HOW MANY REVERSALS?
    [~, nrevs] = is_reversal(data(start_trial:end), 'plot', false); 
    display(['Reversals: ' num2str(nrevs)]); 

    %% SET PLAYER STATE
    %   If we've encountered the desired number of reversals, then set the
    %   player state to exit. 
    %
    %   Had to change logic here so we exit if have have max_revs or more.   
    if nrevs >= max_revs
        d.player.state = 'exit';
    end % if nrevs 
end % if trial >= start_trial 