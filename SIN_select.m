function [selection_text, selection_index] = SIN_select(options, varargin)
%% DESCRIPTION:
%
%   This creates a simple GUI to aid the selection of various types of
%   options. Originally designed as a helper function for the dynamic
%   selection of playback and recording devices through PsychToolBox.
%
% INPUT:
%
%   options:    class containing data options. Supported classes include :
%                   - struct
%                   - cell
%                   - double/single
%                   - char
%   
% Parameters:
%
%   'title':    string, title of figure.
%
%   'prompt':   string, user prompt (e.g., 'Select the playback device')
%
%   'max_selections':   maximum number of selections the user can make in
%                       the dropdown box. 
%
%                       Note: if set to -1, the user will be able to select
%                       all options. 
%
% OUTPUT:
%
%   selection_text:  the selection made
%
% Christopher W Bishop
%   University of Washington
%   10/14

%% GET PARAMETERS
d=varargin2struct(varargin{:});

%% CONVER OPTIONS INTO A TEXT STRING
%   Text string will be placed in the description field of Selection_GUI.m.
description = class2txt(options);

%% OPEN GUI
%   Pass description to Selection_GUI
[selection_index, h] = Selection_GUI('description', {description}, 'title', d.title, 'prompt', d.prompt, 'max_selections', d.max_selections); 

%% NOW RETURN THE OPTION
selection_text = options(selection_index); 

% Close the figure
close(h)