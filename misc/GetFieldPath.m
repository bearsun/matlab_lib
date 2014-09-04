function [s,bPathExists] = GetFieldPath(s,varargin)
% GetFieldPath
% 
% Description:	safely get an element of a multi-level struct
% 
% Syntax:	[x,bPathExists] = GetFieldPath(s,[k]=1,f1,...,fN)
% 
% In:
% 	s	- a struct
%	[k]	- an array of indices from which to get the field in the corresponding
%		  substruct.  will be filled with ones to length N
%	fK	- the Kth element
% 
% Out:
% 	x			- s(k(1)).f1(k(2)).....fN if the path exists, [] otherwise
%	bPathExists	- true if the path exists, false otherwise
% 
% Updated:	2010-09-01
% Copyright 2010 Alex Schlegel (schlegel@gmail.com).  All Rights Reserved.
nVar	= numel(varargin);

if nVar>0 && ~ischar(varargin{1})
	k			= varargin{1};
	cFieldPath	= varargin(2:end);
else
	k			= [];
	cFieldPath	= varargin;
end

nField			= numel(cFieldPath);
k(end+1:nField)	= 1;

bPathExists	= true;
for kF=1:nField
	if isstruct(s) && numel(s)>=k(kF) && isfield(s,cFieldPath{kF})
		s	= s(k(kF)).(cFieldPath{kF});
	else
		s			= [];
		bPathExists	= false;
		return;
	end
end
