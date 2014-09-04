function Clear(ifo)
% PTB.Info.Clear
% 
% Description:	clear the info struct
% 
% Syntax:	ifo.Clear()
% 
% Updated: 2011-12-14
% Copyright 2011 Alex Schlegel (schlegel@gmail.com).  This work is licensed
% under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
% License.
global PTBIFO;

PTBIFO	= struct;
