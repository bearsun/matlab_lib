function Close(lg)
% Group.Log.Close
% 
% Description:	close the log file
% 
% Syntax:	lg.Close()
% 
% Updated: 2011-12-27
% Copyright 2011 Alex Schlegel (schlegel@gmail.com).  This work is licensed
% under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
% License.
if lg.Info.Get('save')
%close the log
	lg.root.File.Close(lg.type);
%stop the diary
	diary off;
%show some info
	strStatusLog	= ['log saved to: "' lg.root.File.Get(lg.type) '"'];
	lg.root.Status.Show(strStatusLog,'time',false);
	
	strStatusDiary	= ['diary saved to: "' lg.root.File.Get([lg.type '_diary']) '"'];
	lg.root.Status.Show(strStatusDiary,'time',false);
end
