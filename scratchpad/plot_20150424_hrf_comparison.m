% For old plotting scripts, see scratchpad/archived/plotting-scripts/*

% Script to generate plots from data capsules in 20150424_hrf_comparison.mat
% See also create_20150424_hrf_comparison.m

%
% TODO: Consider restoring automatic date labeling using this construct:
% ['.....' FormatTime(nowms,'yyyymmdd_HHMM') '.....'];

function [hF,hAlex] = plot_20150424_hrf_comparison

hF				= zeros(1,0);
hAlex			= cell(1,0);
p				= Pipeline;
stem			= '20150424_hrf_comparison';

load(['../data_store/' stem '.mat']);


% Capsule 1 multiplots

fixedPairs		= {	'WSum'		, 0.2		  ...
				  };
ha				= p.renderMultiLinePlot(cCapsule{1},'nTBlock'	, ...
					'lineVarName'			, 'nDataPerRun'		, ...
					'lineVarValues'			, {24 48 72 96}		, ...
					'horizVarName'			, 'hrf'				, ...
					'horizVarValues'		, {0 1}				, ...
					'vertVarName'			, 'nRun'			, ...
					'vertVarValues'			, {5 20}			, ...
					'fixedVarValuePairs'	, fixedPairs		  ...
				);
hF(end+1)		= ha.hF;
hAlex{end+1}	= ha;

ha				= p.renderMultiLinePlot(cCapsule{1},'nTBlock'	, ...
					'lineVarName'			, 'nRun'			, ...
					'lineVarValues'			, {5 10 15 20}		, ...
					'horizVarName'			, 'hrf'				, ...
					'horizVarValues'		, {0 1}				, ...
					'vertVarName'			, 'nDataPerRun'		, ...
					'vertVarValues'			, {24 72}			, ...
					'fixedVarValuePairs'	, fixedPairs		  ...
				);
hF(end+1)		= ha.hF;
hAlex{end+1}	= ha;

ha				= p.renderMultiLinePlot(cCapsule{1},'nDataPerRun'	, ...
					'lineVarName'			, 'nTBlock'			, ...
					'lineVarValues'			, {1 2 4 6 8}		, ...
					'horizVarName'			, 'hrf'				, ...
					'horizVarValues'		, {0 1}				, ...
					'vertVarName'			, 'nRun'			, ...
					'vertVarValues'			, {5 20}			, ...
					'fixedVarValuePairs'	, fixedPairs		  ...
				);
hF(end+1)		= ha.hF;
hAlex{end+1}	= ha;

ha				= p.renderMultiLinePlot(cCapsule{1},'nDataPerRun'	, ...
					'lineVarName'			, 'nRun'			, ...
					'lineVarValues'			, {5 10 15 20}		, ...
					'horizVarName'			, 'hrf'				, ...
					'horizVarValues'		, {0 1}				, ...
					'vertVarName'			, 'nTBlock'			, ...
					'vertVarValues'			, {1 12}			, ...
					'fixedVarValuePairs'	, fixedPairs		  ...
				);
hF(end+1)		= ha.hF;
hAlex{end+1}	= ha;

ha				= p.renderMultiLinePlot(cCapsule{1},'nRun'		, ...
					'lineVarName'			, 'nTBlock'			, ...
					'lineVarValues'			, {1 2 4 6 8}		, ...
					'horizVarName'			, 'hrf'				, ...
					'horizVarValues'		, {0 1}				, ...
					'vertVarName'			, 'nDataPerRun'		, ...
					'vertVarValues'			, {24 72}			, ...
					'fixedVarValuePairs'	, fixedPairs		  ...
				);
hF(end+1)		= ha.hF;
hAlex{end+1}	= ha;

ha				= p.renderMultiLinePlot(cCapsule{1},'nRun'		, ...
					'lineVarName'			, 'nDataPerRun'		, ...
					'lineVarValues'			, {24 48 72 96}		, ...
					'horizVarName'			, 'hrf'				, ...
					'horizVarValues'		, {0 1}				, ...
					'vertVarName'			, 'nTBlock'			, ...
					'vertVarValues'			, {1 12}			, ...
					'fixedVarValuePairs'	, fixedPairs		  ...
				);
hF(end+1)		= ha.hF;
hAlex{end+1}	= ha;


% Capsule 2 multiplots

wsums			= 0.1:0.05:0.3;
ha				= p.renderMultiLinePlot(cCapsule{2},'CRecurX'	, ...
					'lineVarName'			, 'WSum'			, ...
					'lineVarValues'			, num2cell(wsums)	, ...
					'horizVarName'			, 'hrf'				, ...
					'horizVarValues'		, {0 1}				  ...
				);
hF(end+1)		= ha.hF;
hAlex{end+1}	= ha;

recurxs			= 0.1:0.2:0.9;
ha				= p.renderMultiLinePlot(cCapsule{2},'WSum'		, ...
					'lineVarName'			, 'CRecurX'			, ...
					'lineVarValues'			, num2cell(recurxs)	, ...
					'horizVarName'			, 'hrf'				, ...
					'horizVarValues'		, {0 1}				  ...
				);
hF(end+1)		= ha.hF;
hAlex{end+1}	= ha;


% Capsule 3 multiplots

fracs			= 0.1:0.2:0.9;
pcts			= 10:20:90;
pctLabels		= arrayfun(@(pct)sprintf('CRecurY:WSum = %d:%d',pct,100-pct),...
					pcts,'uni',false);

ha				= p.renderMultiLinePlot(cCapsule{3},'NoiseY'	, ...
					'lineVarName'			, '%recur::sum'		, ...
					'lineVarValues'			, num2cell(pcts)	, ...
					'lineLabels'			, pctLabels			, ...
					'horizVarName'			, 'hrf'				, ...
					'horizVarValues'		, {0 1}				  ...
				);
hF(end+1)		= ha.hF;
hAlex{end+1}	= ha;

ha				= p.renderMultiLinePlot(cCapsule{3},'%recur::sum'	, ...
					'lineVarName'			, 'NoiseY'				, ...
					'lineVarValues'			, num2cell(fracs)		, ...
					'horizVarName'			, 'hrf'					, ...
					'horizVarValues'		, {0 1}					  ...
				);
hF(end+1)		= ha.hF;
hAlex{end+1}	= ha;

ha				= p.renderMultiLinePlot(cCapsule{3},'CRecurY'	, ...
					'lineVarName'			, '%recur::sum'		, ...
					'lineVarValues'			, num2cell(pcts)	, ...
					'lineLabels'			, pctLabels			, ...
					'horizVarName'			, 'hrf'				, ...
					'horizVarValues'		, {0 1}				  ...
				);
hF(end+1)		= ha.hF;
hAlex{end+1}	= ha;

ha				= p.renderMultiLinePlot(cCapsule{3},'CRecurY'	, ...
					'lineVarName'			, 'NoiseY'			, ...
					'lineVarValues'			, num2cell(fracs)	, ...
					'horizVarName'			, 'hrf'				, ...
					'horizVarValues'		, {0 1}				  ...
				);
hF(end+1)		= ha.hF;
hAlex{end+1}	= ha;

ha				= p.renderMultiLinePlot(cCapsule{3},'WSum'		, ...
					'lineVarName'			, '%recur::sum'		, ...
					'lineVarValues'			, num2cell(pcts)	, ...
					'lineLabels'			, pctLabels			, ...
					'horizVarName'			, 'hrf'				, ...
					'horizVarValues'		, {0 1}				  ...
				);
hF(end+1)		= ha.hF;
hAlex{end+1}	= ha;

ha				= p.renderMultiLinePlot(cCapsule{3},'WSum'		, ...
					'lineVarName'			, 'NoiseY'			, ...
					'lineVarValues'			, num2cell(fracs)	, ...
					'horizVarName'			, 'hrf'				, ...
					'horizVarValues'		, {0 1}				  ...
				);
hF(end+1)		= ha.hF;
hAlex{end+1}	= ha;



figfilepath		= ['scratchpad/figfiles/' stem '.fig'];
savefig(hF(end:-1:1),figfilepath);
fprintf('Plots saved to %s\n',figfilepath);

end

