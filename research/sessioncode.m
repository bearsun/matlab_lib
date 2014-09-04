function strCode = sessioncode(strInit,t)
% sessioncode
% 
% Description:	construct a session code string
% 
% Syntax:	strCode = sessioncode(strInit,t)
% 
% In:
% 	strInit	- the subject initials
%	t		- the session time
% 
% Out:
% 	strCode	- the session code
% 
% Updated: 2014-03-14
% Copyright 2014 Alex Schlegel (schlegel@gmail.com).  This work is licensed
% under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
% License.
strDate	= lower(FormatTime(t,'ddmmmyy'));
strCode	= [strDate strInit];
