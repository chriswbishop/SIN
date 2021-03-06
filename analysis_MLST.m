function results = analysis_MLST(results, varargin)
%% DESCRIPTION:
%
%   Function to analyze results from MLST. 
%
% INPUT:
%
%   results:    results structure from player_main
%
% Parameters:
%
%   'plot': bool, plot percentage correct. 
%
% OUTPUT:
%
%   results:    updated results structure with stored results information.
%
% Development:
%
%   1. Set flag for analyzing data by subcategory (e.g., high density, low
%   density, etc.).
%
% References:
%
%   1. Krick, Prusick, French, Gotch, Eisenberg, Young. "Assessing Spoken
%   Word Recognition in Children Who Are Deaf or Hard of Hearing: A
%   Translational Approach." J Am Acad Audiol 23:464-475 (2012)
%
% Christopher W Bishop
%   University of Washington
%   9/14

%% GET INPUT PARAMETERS
d=varargin2struct(varargin{:});

%% GET SCORING INFORMATION FOR EACH TRIAL
cell_score = results.RunTime.player.modcheck.score; 
score = [];
%% FIND ALL SCORED ITEMS IN ALL TRIALS
for i=1:numel(cell_score)
    tscore = cell_score{i}; 
    score = [score; tscore(tscore ~= -1)];    
end % for i=1:numel(score

%% COMPUTE PERCENTAGE CORRECT
correct_items = numel(find(score == 1));
scored_items = numel(score);
percentage_correct = correct_items / scored_items * 100;
%% ADD TO RESULTS STRUCTURE
results.RunTime.analysis.results = struct(...
    'percentage_correct',   percentage_correct, ...
    'scored_items', scored_items, ...
    'correct_items', numel(find(score == 1))); 

%% PLOT RESULTS
if d.plot
    
    % Bar plot
    figure
    bar(1, percentage_correct); 
    
    % Set axis limits
    xlim([0 2]);
    ylim([0 100]); 
    
    % Markup
    title(results.RunTime.specific.testID); 
    ylabel(sprintf(['Percentage Correct\n(out of ' num2str(scored_items)])); 
    label_datapoint(1, percentage_correct + 5, ...
        'text', [num2str(percentage_correct) '%'], ...
        'color', 'b', ...
        'fontsize', 12, ...
        'fontweight', 'bold');
    
end % if d.play