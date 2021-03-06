function [Y, d]=modifier_PlaybackControl(X, mod_code, varargin)
%% DESCRIPTION:
%
%   Function designed to handle basic playback control requests. At time of
%   writing, this includes "pause", "run/resume", and "exit/quit". 
%
% INPUT:
%
%   X:  time series
%
%   mod_code:   modification code. Will respond to codes 99 (pause), 100
%               (resume), and 86 (quit). All other codes have no effect. 
%
% OUTPUT:
%
%   Y:  zeroed time series
%
%   d:  altered data structure with player state set to 'pause'. 
%
% Christopher W. Bishop
%   University of Washington
%   5/14

d=varargin2struct(varargin{:}); 

% The player is made to work with a "SIN" style structure. If the user has
% defined inputs just at the commandline, then reassign to make it
% compatible.
if ~isfield(d, 'player')
    d.player = d; 
end % if

%% GET IMPORTANT VARIABLES FROM SANDBOX
% trial = d.sandbox.trial; 
modifier_num=d.sandbox.modifier_num; 

%% INITIALIZATION
if ~isfield(d.player.modifier{modifier_num}, 'initialized') || isempty(d.player.modifier{modifier_num}.initialized), d.player.modifier{modifier_num}.initialized=false; end

% If we are initializing the modifier, kick back the (unmodified) data and
% set the modifier initialized flag.
if ~d.player.modifier{modifier_num}.initialized
    
    % Set the initialization flag
    d.player.modifier{modifier_num}.initialized=true;
    
    % To be safe, assign input to output. 
    Y=X; 
    
    return
    
end % if ~d.player.modifier{modifier_num}.initialized

% Switch to change state of player
switch mod_code
    
    case {86}
        d.player.state='exit';
    case {99}
%         % pause code
        d.player.state='pause';
    case {100}
        d.player.state='run'; 
    otherwise

end % switch

% State actions
%   For 'pause' or 'exit' states, we want sound playback to stop, so zero
%   out the playback data. 
%
%   While in 'run' state, kick back the (unaltered) data
switch d.player.state
    case {'pause' 'exit'}
        Y = zeros(size(X)); 
    case 'run'
        Y = X; 
    otherwise
        error('Unknown state')
%         Y = X;
end % switch