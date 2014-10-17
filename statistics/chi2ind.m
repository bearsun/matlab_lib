function [h,p,stats] = chi2ind(ct,varargin)
% chi2ind
% 
% Description:	perform a chi-square test for independence on a 2x2 contingency
%				table
% 
% Syntax:	[h,p,stats] = chi2ind(ct,<options>)
% 
% In:
% 	ct	- the 2x2 contingency table. each row is the data from one group, and
%		  each column is a label that can be assigned to a group member. e.g.
%		  are democrats more likely to be female than republicans?
%						male	female
%			democrat	  5       7
%			republican	  8       6
% <options>:
%		yates:	(false) true to apply Yates' correction
%		alpha:	(0.05) the significance cutoff
% 
% Out:
% 	h		- true if the null hypothesis should be rejected
%	p		- the p-value
%	stats	- a struct of stats
% 
% Notes:
%	adapted from http://www.mathworks.com/matlabcentral/answers/96572-how-can-i-perform-a-chi-square-test-to-determine-how-statistically-different-two-proportions-are-in
% 
% Updated: 2014-09-04
% Copyright 2014 Alex Schlegel (schlegel@gmail.com).  This work is licensed
% under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
% License.
opt	= ParseArgs(varargin,...
		'yates'	, false	, ...
		'alpha'	, 0.05	  ...
		);

nL	= sum(ct,1);
nG	= sum(ct,2);
nT	= sum(ct(:));

fL1E	= nL(1)/nT;
fL2E	= 1 - fL1E;
fE		= repmat([fL1E fL2E],[2 1]);
nE		= fE.*repmat(nG,[1 2]);

observed	= reshape(ct,[],1);
expected	= reshape(nE,[],1);

yates			= conditional(opt.yates,0.5,0);
stats.chi2stat	= sum( (abs(observed - expected) - yates).^2./expected);
stats.df		= 1;

p	= 1 - chi2cdf(stats.chi2stat,stats.df);
h	= p <= opt.alpha;