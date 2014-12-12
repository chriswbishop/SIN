function wordspan_find_keywords(file_list, varargin)
%% DESCRIPTION:
%
%   This will load the provided word span stimulus files and return just
%   the time trace of the keywords within each sentence. This proved useful
%   when trying to calibrate the word span since the carrier phrase does
%   not vary (much) from one sentence to the next.
%
%   We will need to build in some sanity checks on the carrier phrase from
%   sentence to sentence to make sure it hasn't changed fundamentally in
%   some way (e.g., through error or other machinations). 
%
% INPUT:
%
%   file_list:  cell array, paths to word span files. 
%
% Parameters:
%
% OUTPUT:
%
%   XXX
%
% Development:
%
%   None (yet).
%
% Christopher W Bishop
%   University of Washington
%   12/14

%% GATHER INPUT PARAMETERS 
d = varargin2struct(varargin{:});

%% INITIALIZE RETURN VARIABLES
key_word_timeseries = cell(numel(file_list),1); 

%% PROCESS SENTENCES
for i=1:numel(file_list)
    
    
    
end % for i=1:numel(file_list) 