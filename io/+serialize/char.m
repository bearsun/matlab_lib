function str = char(x,varargin)
% serialize.char
% 
% Description:	serialize a character array
% 
% Syntax:	str = serialize.char(x,<options>)
% 
% Updated: 2014-01-31
% Copyright 2014 Alex Schlegel (schlegel@gmail.com).  This work is licensed
% under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
% License.
sz	= size(x);
nd	= numel(sz);

if nd==2
	if sz(1)==1
		str	= ['''' strrep(x,'''','''''') ''''];
	else
		cRow	= cell(sz(1),1);
		for kR=1:sz(1)
			cRow{kR}	= serialize.char(x(kR,:),varargin{:});
		end
		
		str	= ['[' join(cRow,';') ']'];
	end
else
	cX		= cell(sz(end),1);
	cRefPre	= repmat({':'},[nd-1 1]);
	
	for k=1:sz(end)
		cX{k}	= x(cRefPre{:},k);
	end
	
	str	= serialize.call('cat',[nd;cX],varargin{:});
end
