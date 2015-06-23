% Copyright (c) 2015 Trustees of Dartmouth College. All rights reserved.

% This script is an updated variant of s20150605_plot_thresholds.m
%
% Among other differences, the variants of this script use different
% data formats.  Data files written by one variant can be plotted only
% by the same variant.

% TODO: Comments
%

function h = s20150618_plot_thresholds(varargin)
	stem		= 's20150618_thresholds';
	opt			= ParseArgs(varargin, ...
					'clip'				, false			, ...
					'fakedata'			, []			, ...
					'forcegen'			, false			, ...
					'nogen'				, []			, ...
					'noplot'			, []			, ...
					'plottype'			, []			, ...
					'savedata'			, []			, ...
					'saveplot'			, false			, ...
					'showwork'			, false			, ...
					'varname'			, []			, ...
					'xstart'			, 0.06			, ...
					'xstep'				, 0.02			, ...
					'xend'				, 0.34			  ...
					);
	extraargs	= opt2cell(opt.opt_extra);

	hasFigwin		= feature('ShowFigureWindows');
	opt.fakedata	= unless(opt.fakedata,hasFigwin);
	opt.nogen		= unless(opt.nogen,hasFigwin) && ~opt.forcegen;
	opt.noplot		= unless(opt.noplot,~hasFigwin);
	opt.savedata	= unless(opt.savedata,~opt.fakedata);

	if opt.showwork
		opt.plottype	= unless(opt.plottype,{'multifit'});
		opt.varname		= unless(opt.varname,'WStrength');
	elseif isempty(opt.plottype)
		opt.plottype	= conditional(isempty(opt.varname),{'multifit'},...
							{'multifit','p_snr','p_test','test_snr'});
	elseif ~iscell(opt.plottype)
		opt.plottype	= {opt.plottype};
	end

	timestamp	= FormatTime(nowms,'yyyymmdd_HHMMSS');
	h			= [];
	cap_ts		= {};

	sketch('nRun'		, 2:20);
	sketch('nSubject'	, 1:20);
	sketch('nTBlock'	, 1:20);
	sketch('nRepBlock'	, 2:15);
	sketch('WStrength'	, 0.2:0.001:0.8);

	if numel(h) > 0
		if ~opt.saveplot
			fprintf('Skipping save of plot(s) to fig file.\n');
		else
			cap_ts		= sort(cap_ts);
			dirpath		= 'scratchpad/figfiles';
			prefix		= sprintf('%s_%s',cap_ts{end},stem);
			kind		= unless(opt.varname,strjoin(opt.plottype,'+'));
			if opt.clip
				kind	= [kind '-clipped'];
			end
			figfilepath	= sprintf('%s/%s-%s-%s.fig',dirpath,prefix,kind,FormatTime(nowms,'mmdd'));
			savefig(h(end:-1:1),figfilepath);
			fprintf('Plot(s) saved to %s\n',figfilepath);
		end
	end

	function sketch(testvarName,testvarValues)
		if ~isempty(opt.varname) && ~strcmp(testvarName,opt.varname)
			return;
		end
		snrrange		= opt.xstart:opt.xstep:opt.xend;
		plex			= opt.xend+testvarValues(end)*1i;
		data_label		= sprintf('%s_%s_%d_%s_%d_%s',stem,testvarName,numel(testvarValues), ...
							'SNR',numel(snrrange),num2str(abs(plex)));
		fcreate_dataset	= conditional(opt.nogen,[],@create_threshCapsule);
		not_before		= conditional(opt.forcegen,timestamp,'00000000_');
		[capsule,ts]	= get_dataset(data_label,fcreate_dataset, ...
							'data_varname'	, 'capsule'		, ...
							'not_before'	, not_before	, ...
							'savedata'		, opt.savedata	, ...
							'timestamp'		, timestamp		  ...
							);
		if opt.noplot || isempty(capsule)
			return;
		elseif ~isfield(capsule.version,'thresholdCapsule')
			error('Not a threshold capsule.');
		elseif ~strcmp(capsule.version.thresholdCapsule,stem)
			error('Incompatible capsule version %s',capsule.version.thresholdCapsule);
		end
		points		= capsule.points;
		pThreshold	= capsule.threshopt.pThreshold;

		plottype	= opt.plottype;
		nAV	= numel(plottype);
		for kAV=1:nAV
			switch plottype{kAV}
				case 'multifit'
					plotfn	= @linefit_test_vs_SNR;
				case 'p_snr'
					plotfn	= @scatter_p_vs_SNR;
				case 'p_test'
					plotfn	= @scatter_p_vs_test;
				case 'test_snr'
					plotfn	= @scatter_test_vs_SNR;
				otherwise
					error('Unknown plottype ''%s''',plottype{kAV});
			end
			h(end+1)		= plotfn(points,pThreshold,testvarName,opt); %#ok
			cap_ts{end+1}	= ts; %#ok
		end

		function capsule = create_threshCapsule
			start_ms	= nowms;

			[threshPts,pipeline,threshOpt]	...
						= ThresholdSketch(...
							'fakedata'	, opt.fakedata		, ...
							'noplot'	, true				, ...
							'yname'		, testvarName		, ...
							'yvals'		, testvarValues		, ...
							'xstart'	, opt.xstart		, ...
							'xstep'		, opt.xstep			, ...
							'xend'		, opt.xend			, ...
							'seed'		, 0					, ...
							extraargs{:} ...
							);
			end_ms		= nowms;
			version		= struct(...
							'pipeline'			, pipeline.version.pipeline	, ...
							'thresholdCapsule'	, stem						  ...
							);

			capsule.begun		= FormatTime(start_ms);
			capsule.id			= FormatTime(start_ms,'yyyymmdd_HHMMSS');
			capsule.label		= data_label;
			capsule.version		= version;
			capsule.uopt		= pipeline.uopt;
			capsule.threshopt	= threshOpt;
			capsule.points		= threshPts;
			capsule.elapsed_ms	= end_ms - start_ms;
			capsule.done		= FormatTime(end_ms);
		end
	end
end

function [dataset,ts] = get_dataset(data_label,fcreate_dataset,varargin)
% TODO: This disk-data memoization function (i.e., caching and
% retrieval function) is reasonably generic and should be usable for
% datasets other than capsules.  Should perhaps make it into a
% standalone function, or perhaps into a disk-data memoization class.
	opt		= ParseArgs(varargin, ...
				'data_varname'	, 'dataset'			, ...
				'not_before'	, '20150101_'		, ...
				'savedata'		, true				, ...
				'timestamp'		, []				  ...
				);
	dirpath			= '../data_store';
	filenames		= split(ls(dirpath),'\n');
	suffix			= sprintf('_%s.mat',data_label);
	filename_regexp	= sprintf('^[_\\d]{4,}%s$',suffix);
	matches			= filenames(~cellfun(@isempty,regexp(filenames,filename_regexp)));
	sorted_names	= sort(cat(1,matches,{opt.not_before}));
	recent_names	= sorted_names((1+find(strcmp(opt.not_before,sorted_names))):end);
	if numel(recent_names) == 0
		if isempty(fcreate_dataset)
			fprintf('Preexisting %s not available for %s\n',opt.data_varname,data_label);
			dataset	= [];
			ts		= [];
		else
			fprintf('Creating new %s for %s\n',opt.data_varname,data_label);
			dataset	= fcreate_dataset();
			ts		= unless(opt.timestamp,FormatTime(nowms,'yyyymmdd_HHMMSS'));
			if opt.savedata
				path	= sprintf('%s/%s%s',dirpath,ts,suffix);
				eval(sprintf('%s = dataset;',opt.data_varname));
				save(path,opt.data_varname);
				fprintf('Saved %s to %s\n',opt.data_varname,path);
			end
		end
	else
		fprintf('Using preexisting %s for %s\n',opt.data_varname,data_label);
		newest_name	= recent_names{end};
		path		= sprintf('%s/%s',dirpath,newest_name);
		fprintf('Loading %s\n',path);
		content		= load(path);
		dataset		= content.(opt.data_varname);
		ts_regexp	= sprintf('^(.*)%s$',suffix);
		ts			= regexprep(newest_name,ts_regexp,'$1');
	end
end

function h = linefit_test_vs_SNR(sPoint,pThreshold,varname,opt)
	showwork	= conditional(nottrue(opt.showwork),opt.showwork,'scat');
	xvals		= [sPoint.x];
	yvals		= [sPoint.y];
	pvals		= max(1e-6,min([sPoint.p],1e6));
	summaryvals	= [sPoint.summary];
	snr			= unique(xvals);
	nsnr		= numel(snr);

	nline			= 5; % At present, five plot lines
	cploty			= cell(1,nline);
	cploterr		= cell(1,nline);
	[cploty{:}]		= deal(NaN(1,nsnr));
	[cploterr{:}]	= deal(zeros(1,nsnr));
	errfac			= 1; % For cploterr error bars at 50%; TODO: revise

	log10pThreshold	= log10(pThreshold);

	for ks=1:nsnr
		b				= xvals == snr(ks);
		currNProbe		= sum(b);
		if currNProbe < 2
			continue;
		end
		y			= yvals(b);
		logp		= log10(pvals(b));
		summary		= summaryvals(b);
		sorted_logp	= sort(logp);
		fourth_logp	= sorted_logp(min(4,end));

		uy_at_snr	= unique(y);
		nuy_at_snr	= numel(uy_at_snr);
		logp_mean_t	= zeros(size(logp));
		percentile	= zeros(size(logp));
		for ky=1:nuy_at_snr
			b			= (y == uy_at_snr(ky));
			usummary	= summary(b);
			tstat		= arrayfun(@(s)s.alex.stats.tstat,usummary);
			df			= arrayfun(@(s)s.alex.stats.df,usummary);
			if var(df)==0
				logp_mean_t(b)	= log10(max(1e-6,min(t2p(mean(tstat),mean(df)),1e6)));
			end
			percentile(b)	= 100*sum(arrayfun(@(v) v<=log10pThreshold,logp(b)))/sum(b);
		end

		[f_logp,g_logp]	= dual_linefit(logp,y,log10pThreshold);
		[f_mean,g_mean]	= dual_linefit(logp_mean_t,y,log10pThreshold);
		[f_pct,~]		= dual_linefit(percentile,y,50);

		criterionfit	= g_logp.px2y;
		if notfalse(showwork) && ks < 8
			% the diagnostic scatter-plot below places the "y" value on the x-axis
			% and log10(p) on the y-axis, in effect swapping the axes of the polyfit.
			curr_snr	= num2str(snr(ks));
			fprintf('Num probes for SNR=%s is %d; ',curr_snr,currNProbe);
			fprintf('slope of fitted line is %s;\n',num2str(1/criterionfit(1)));
			fprintf('fourth-smallest log is %s\n',num2str(fourth_logp));

			logpthreshStr	= sprintf('log(%s)',num2str(pThreshold));
			xlabelStr		= sprintf('%s (also referred to here as y)',varname);
			figure;
			switch showwork
				case 'hist'
					hist(y); % TODO: use optional args to generate more informative histogram
				case 'pct'
					scatter(y,percentile);
					xlabel(xlabelStr);
					ylabel(sprintf('%% p <= %s',num2str(pThreshold)));
				case 'scat'
					scatter(y,logp_mean_t,'red','fill');
					xlabel(xlabelStr);
					ylabel('log_{10}(p)');
					hold;
					scatter(y,logp,'blue');
					ySamp		= linspace(min(y),max(y),2);
					f_meanSamp	= getLogpSamp(f_mean,2);
					f_logpSamp	= getLogpSamp(f_logp,2);
					plot(ySamp,polyval(g_mean.py2x,ySamp),'red');
					plot(ySamp,polyval(g_logp.py2x,ySamp),'blue');
					plot(polyval(f_mean.px2y,f_meanSamp),f_meanSamp,'green');
					plot(polyval(f_logp.px2y,f_logpSamp),f_logpSamp,'yellow');
					plot([min(y),max(y)],[log10pThreshold,log10pThreshold],'black');
					legend({'log p(mean t)','all probes','log(p(mean t))=g(y)','log(p)=G(y)','y=f(log(p(mean t)))','y=F(log(p))',logpthreshStr});
				otherwise
					error('Unknown showwork type ''%s''',showwork);
			end
			title(sprintf('Distrib of %s probes at SNR=%s',varname,curr_snr));
			hold off;
			if strcmp(showwork,'scat') && ks == 4 && false % (omit for now)
				alexplot(y,logp,'type','scatter','color',[0,0,1]);
			end
		end
		if ~(currNProbe < 20 || criterionfit(1) >= 0 || fourth_logp > log10pThreshold) % TODO: change criterion
			cploty{1}(ks)	= g_mean.y0;
			cploty{2}(ks)	= g_logp.y0;
			cploty{3}(ks)	= f_mean.y0;
			cploty{4}(ks)	= f_logp.y0;
			cploty{5}(ks)	= f_pct.y0;
			cploterr{1}(ks)	= g_mean.dy0;
			cploterr{2}(ks)	= g_logp.dy0;
			cploterr{3}(ks)	= f_mean.dy0;
			cploterr{4}(ks)	= f_logp.dy0;
			cploterr{5}(ks)	= f_pct.dy0;
		end
	end
	titleStr	= sprintf('%s vs SNR to achieve p=%s',varname,num2str(pThreshold));
	pctLegend	= sprintf('Fit: P(p <= %s)=50%%',num2str(pThreshold));
	cLegend		= {'Fit: g(y)=log(p(mean t))','Fit: G(y)=log(p)','Fit: f(log(p(mean t)))=y','Fit: F(log(p))=y',pctLegend};

	hA	= alexplot(snr,cploty, ...
			'error'		, cploterr				, ...
			'title'		, titleStr				, ...
			'xlabel'	, 'SNR'					, ...
			'ylabel'	, varname				, ...
			'legend'	, cLegend				, ...
			'errortype'	, 'bar'					  ...
			);
	h	= hA.hF;

	function [f,g] = dual_linefit(x,y,x0)
		%fprintf('range(x)=%s range(y)=%s\n',num2str(range(x)),num2str(range(y)));
		xy	= [x(:);y(:)];
		if range(x) == 0 || range(y) == 0 || any(isnan(xy)) || any(isinf(xy))
			f.px2y			= [0,mean(y)];
			f.py2x			= [0,mean(x)];
			[f.y0,f.dy0]	= deal(NaN);
			g				= f;
		else
			[f.px2y,S]		= polyfit(x,y,1);
			[f.y0,f.dy0]	= polyval(f.px2y,x0,S);
			f.y0			= optclip(f.y0);
			f.dy0			= errfac*f.dy0;
			f.py2x			= swap_linear_polynomial_axes(f.px2y);

			[g.py2x,~]		= polyfit(y,x,1);
			g.px2y			= swap_linear_polynomial_axes(g.py2x);
			g.y0			= polyval(g.px2y,x0);
			g.y0			= optclip(g.y0);
			g.dy0			= 0; % TODO: come up with error metric for this direction
		end
	end

	function samp = getLogpSamp(linefit,nSamp)
		ypreimage	= sort(polyval(linefit.py2x,[min(y),max(y)]));
		samp		= linspace(max(ypreimage(1),min(logp)),min(ypreimage(end),max(logp)),nSamp);
	end

	function y0 = optclip(y0)
		if opt.clip
			y0	= max(min(yvals),min(y0,max(yvals)));
		end
	end

	function pswap = swap_linear_polynomial_axes(p)
		iSlope	= 1/p(1);
		pswap	= [iSlope,-p(2)*iSlope];
	end
end

function h = scatter_p_vs_SNR(sPoint,pThreshold,varname,~)
	h	= scatter_p_vs_x('SNR',[sPoint.x],[sPoint.p],varname,[sPoint.y],pThreshold);
end

function h = scatter_p_vs_test(sPoint,pThreshold,varname,~)
	h	= scatter_p_vs_x(varname,[sPoint.y],[sPoint.p],'SNR',[sPoint.x],pThreshold);
end

function h = scatter_p_vs_x(xname,xvals,pvals,colorname,colorvals,pThreshold)
	log10_p		= log10(max(1e-6,min(pvals,1e6)));
	xdistinct	= unique(xvals);
	xmost		= xdistinct(1:end-1);
	if ~isempty(xmost)
		xgap		= diff(xdistinct);
		nbetween	= ceil(200/numel(xmost));
		dots		= reshape(repmat(xmost,nbetween,1)+(1:nbetween).'*xgap/(nbetween+1),1,[]);
	else
		dots		= [];
	end
	unit		= ones(size(dots));
	scatx		= [xvals dots];
	scaty		= [log10_p log10(pThreshold)*unit];
	color		= [colorvals max(colorvals)*unit];
	h			= figure;
	scatter(scatx,scaty,10,color);
	title(sprintf('log10(p) vs %s, with low %s as blue, high %s as red/brown',xname,colorname,colorname));
end

function h = scatter_test_vs_SNR(sPoint,pThreshold,varname,~)
% TODO: This function is redundant with plot_points in ThresholdSketch.
% Should clean up this redundancy.
	ratio		= max(1e-6,min([sPoint.p]./pThreshold,1e6));
	area		= 10+abs(60*log(ratio));
	leThreshold	= [sPoint.p] <= pThreshold;
	blue		= leThreshold.';
	red			= ~blue;
	green		= zeros(size(red));
	color		= [red green blue];
	h			= figure;
	scatter([sPoint.x],[sPoint.y],area,color);
	title(sprintf('%s vs SNR, with low p as blue, high p as red',varname));
end
