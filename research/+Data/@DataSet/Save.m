function Save(ds,d)
% Data.DataSet.Save
% 
% Description:	save data
% 
% Syntax:	ds.Save(d)
% 
% In:
% 	d	- the data
% 
% Updated: 2013-03-10
% Copyright 2013 Alex Schlegel (schlegel@gmail.com).  This work is licensed
% under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
% License.
status(['saving parsed data for ' ds.name]);

strPathData	= ds.data_path;

save(strPathData,'-struct','d');
