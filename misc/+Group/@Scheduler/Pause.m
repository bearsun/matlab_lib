function Pause(sch,varargin)
% Group.Scheduler.Pause
% 
% Description:	pause a task or the scheduler timer
% 
% Syntax:	sch.Pause([strName])
%
% In:
%	[strName]	- the name of the task to pause.  if unspecified, pauses the
%				  scheduler timer
% 
% Updated: 2011-12-27
% Copyright 2011 Alex Schlegel (schlegel@gmail.com).  This work is licensed
% under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
% License.
if nargin<2
%pause the timer
	if IsTimerRunning(sch.TCheck)
		stop(sch.TCheck);
	end
	
	sch.Info.Set('running',false);
else
%pause a task
	k	= p_Get(sch,varargin{1});
	
	if ~isempty(k)
		sch.root.info.scheduler.task(k).mode	= bitset(sch.root.info.scheduler.task(k).mode,sch.MODE_PAUSED);
	end
end