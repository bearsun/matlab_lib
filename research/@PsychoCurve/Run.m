function Run(p,varargin)
% PsychoCurve.Run
% 
% Description:	run a procedure to probe and fit a psychometric curve
% 
% Syntax:	p.Run(<options>)
% 
% In:
% 	<options>:
%		clear:		(false) true to clear existing data
%		itmin:		(50) the minimum number of iterations
%		itmax:		(100) the maximum number of iterations
%		stop_se:	(0.005) stop if the treshold-estimate standard error reaches
%					this value
%		silent:		(false) true to suppress status messages
% 
% Updated: 2012-02-09
% Copyright 2012 Alex Schlegel (schlegel@gmail.com).  This work is licensed
% under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
% License.
opt	= ParseArgsOpt(varargin,...
		'clear'		, false	, ...
		'itmin'		, 50	, ...
		'itmax'		, 100	, ...
		'stop_se'	, 0.005	, ...
		'silent'	, false	  ...
		);

if opt.clear
	p.Clear;
end

%iterate
	kIt	= 1;
	
	progress(min(opt.itmax,1e6),'label','Fitting Psychometric Curve','silent',opt.silent); 
	while kIt<=opt.itmin || (p.se>opt.stop_se && kIt<=opt.itmax)
		p.Step('plot',p.debug && kIt/10==round(kIt/10),'silent',opt.silent);
		
		kIt	= kIt+1;
		
		progress;
	end
	progress('end');
%one last robust fit
	%p.Fit;
%plot the results
	if p.debug
		p.Plot;
	end
