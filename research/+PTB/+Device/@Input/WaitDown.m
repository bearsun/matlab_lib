function [err,t,kState] = WaitDown(inp,strButton,varargin)
% PTB.Device.Input.WaitDown
% 
% Description:	wait until a button is down
% 
% Syntax:	[err,t,kState] = inp.WaitDown(strButton,[bLog]=true,<options>)
% 
% In:
%	strButton	- the button name
%	[bLog]		- true to add a log event if the button is down
%	<options>:
%		wait_priority:	(PTB.Scheduler.PRIORITY_LOW) only execute scheduler tasks
% 						at or above this priority while waiting for the button
%
% Out:
%	err		- true if any of the bad buttons were down
%	t		- the time associated with the query
%	kState	- an array of the state indices that were down
%
% Updated: 2011-12-24
% Copyright 2011 Alex Schlegel (schlegel@gmail.com).  This work is licensed
% under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
% License.
[bLog,opt]	= ParseArgs(varargin,true,...
				'wait_priority'	, PTB.Scheduler.PRIORITY_LOW	  ...
				);

[b,err]	= deal(false);
while ~b && ~err
	[b,err,t,kState]	= inp.Down(strButton,bLog);
	
	if ~b
		inp.parent.Scheduler.Wait(opt.wait_priority,PTB.Now+50);
	end
end
