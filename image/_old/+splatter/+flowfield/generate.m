function f = generate(x,varargin)
% splatter.flowfield.generate
% 
% Description:	generate a flowfield, given an field of repuslive objects and a
%				flow source point
% 
% Syntax:	f = splatter.flowfield.generate(x,[pSource]=<center, or last source point>,<options>)
% 
% In:
% 	x			- either a 2D array defining the mass at each point of repulsive
%				  objects in a field, or the return from a previous call to the
%				  function
%	[pSource]	- the (row,column) source point
%	<options>:
%		streams:		(100) the number of streams to send through the flow
%						field
%		min_stream_len:	(min(size(x))/2) delete streams shorter than this
%		max_stream_it:	(1000) the maximum number of stream iterations
%		s_init:			(10) the initial stream speed
%		s_cutoff:		(0.01) the speed cutoff, below which streams are
%						abandoned
%		repulsion_exp:	(2) the exponent of the drop off of the repulsive force
%						with distance
%		flow_force:		(1) the constant of the repulsive force away from the
%						source point
% 
% Out:
% 	f	- the flowfield
%
% Examples:
%	n=300; F1=2; F2=1; x = zeros(n); x(n/2:end,n/2)=F1; x(n/2,1:n/2)=F1; x(1,1:n/2)=F2; x(n/2:end,end)=F2; pSource = [2 n-1];
%	f = splatter.flowfield.generate(x,pSource,'streams',1000);
% 
% Updated: 2013-05-19
% Copyright 2013 Alex Schlegel (schlegel@gmail.com).  This work is licensed
% under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
% License.
[pSource,opt]	= ParseArgs(varargin,[],...
					'streams'			, 100	, ...
					'min_stream_len'	, []	, ...
					'max_stream_it'		, 1000	, ...
					's_init'			, 10	, ...
					's_cutoff'			, 0.01	, ...
					'repulsion_exp'		, 1.2	, ...
					'flow_force'		, 2	, ...
					'debug'				, false	  ...
					);

%field size
	if isstruct(x)
		sz	= size(x.obj);
	else
		sz	= size(x);
	end
%process input
	opt.min_stream_len	= unless(opt.min_stream_len,min(sz)/2);
%field positions
	[yField,xField]	= ndgrid(1:sz(1),1:sz(2));

%calculate the repulsive force generated by each pixel object
	if isstruct(x)
		f			= x;
		
		if ~isempty(pSource)
		%recalculate the flow force
			FFlowOld	= FlowForce(f.source);
			FFlowNew	= FlowForce(pSource);
			
			f.F.y	= f.F.y + FFlowNew.y - FFlowOld.y;
			f.F.x	= f.F.x + FFlowNew.x - FFlowOld.x;
			
			f.source	= pSource;
		end
	else
		f.obj		= x;
		f.b			= f.obj~=0;
		f.source	= unless(pSource,sz/2);
		
		%object locations
			[yObj,xObj]	= find(f.b);
			nObj		= numel(yObj);
		%calculate the repulsive force generated by each pixel object
			[f.F.y,f.F.x]	= deal(zeros(sz));
			
			progress(nObj,'label','calculating forces');
			for kO=1:nObj
				%distance
					dy	= yField - yObj(kO);
					dx	= xField - xObj(kO);
					d	= sqrt(dy.^2 + dx.^2);
				%force component vector
					vy	= dy./d;
					vx	= dx./d;
				%repulsive force
					F	= f.obj(yObj(kO),xObj(kO))./d.^opt.repulsion_exp;
					Fy	= F.*vy;
					Fx	= F.*vx;
				
				f.F.y	= f.F.y + Fy;
				f.F.x	= f.F.x + Fx;
				
				progress;
			end
		%add the flow force
			FFlow	= FlowForce(f.source);
			
			f.F.y	= f.F.y + FFlow.y;
			f.F.x	= f.F.x + FFlow.x;
			
			
		f.F.y(f.b)	= NaN;
		f.F.x(f.b)	= NaN;
		
		f.F.m	= sqrt(f.F.y.^2 + f.F.x.^2);
		
		f.im.F		= structfun2(@normalize,f.F);
		f.im.logF	= structfun2(@(x) normalize(log(x)),f.F);
	end
%send streams through the force field
	f.stream.b	= false([sz opt.streams]);
	f.stream.a	= NaN([sz opt.streams],'single');
	
	progress(opt.streams,'label','sending streams');
	
	%initial velocities
		aInit	= randBetween(0,2*pi,[opt.streams 1]);
		vyInit	= opt.s_init*sin(aInit);
		vxInit	= opt.s_init*cos(aInit);
	
	for kS=1:opt.streams
		%initial conditions
			vy	= vyInit(kS);
			vx	= vxInit(kS);
			
			py			= f.source(1);
			px			= f.source(2);
			[pyR,pxR]	= varfun(@round,py,px);
		%follow the stream until it reaches the edge
			[pyLast,pxLast]	= deal(inf);
			kIt				= 0;
			while kIt<opt.max_stream_it && pyR>0 && pyR<=sz(1) && pxR>0 && pxR<=sz(2) && ~f.b(pyR,pxR) && dist([py px],[pyLast pxLast])>=opt.s_cutoff
				pyLast	= py;
				pxLast	= px;
				
				%add the point and its direction
					f.stream.b(pyR,pxR,kS)	= true;
					f.stream.a(pyR,pxR,kS)	= atan2(vy,vx);
				%calculate the new velocity and position
					%current force
						Fy	= f.F.y(pyR,pxR);
						Fx	= f.F.x(pyR,pxR);
					%find the change in time that makes us move one pixel
					%we need, for the new dy and dx, dt*sqrt(vy^2+vx^2)==1
						R	= roots([Fy^2+Fx^2 2*(vy*Fy+vx*Fx) vy^2+vx^2 0 -1]);
						dt	= R(imag(R)==0 & R>0);
						
						if numel(dt)>1
						%must be some kind of error in roots
							delta	= ((vy + Fy*dt).*dt).^2 + ((vx + Fx*dt).*dt).^2;
							Ddelta	= abs(delta-1);
							dt		= dt(find(Ddelta==min(Ddelta),1));
						end
						
					if ~isempty(dt)
					%new velocity
						vy	= vy + Fy*dt;
						vx	= vx + Fx*dt;
					%new position
						py			= py + vy.*dt;
						px			= px + vx.*dt;
						[pyR,pxR]	= varfun(@round,py,px);
					end
				
				kIt	= kIt+1;
			end
		
		progress;
	end
	
	%delete short streams
		lenStream	= squeeze(sum(sum(f.stream.b,1),2));
		bDelete		= lenStream<opt.min_stream_len;
		
		f.stream.b(:,:,bDelete)	= [];
		f.stream.a(:,:,bDelete)	= [];
	
	f.im.stream.all			= any(f.stream.b,3);
	
	cRed	= ~f.b.*min(1,f.im.stream.all + f.im.F.m);
	cOther	= f.im.F.m.*~f.im.stream.all;
	f.im.stream.composite	= cat(3,cRed,cOther,cOther);

%------------------------------------------------------------------------------%
function F = FlowForce(p)
	dy		= yField - p(1);
	dx		= xField - p(2);
	d		= sqrt(dy.^2 + dx.^2);
	
	d(d==0)	= 1;
	
	F.y	= opt.flow_force.*dy./d;
	F.x	= opt.flow_force.*dx./d;
end
%------------------------------------------------------------------------------%

end
