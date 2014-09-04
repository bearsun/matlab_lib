function [s,extra] = sfn(query)
% neurojobs.site.sfn
% 
% Syntax:	[s,extra] = neurojobs.site.sfn(query)
% 
% Updated: 2014-09-02
% Copyright 2014 Alex Schlegel (schlegel@gmail.com).  This work is licensed
% under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
% License.
url				= 'http://neurojobs.sfn.org/jobs/?keywords=&type=full-time&education=doctorate&sort=DATE_POSTED%20DESC&resultsPerPage=100';
[node,extra]	= neurojobs.site.fetch(url);

div		= neurojobs.parse.extract(node,'http://schema.org/JobPosting','type','attr','attr','itemtype','tag','div');
detail	= neurojobs.parse.extract(div,'bti-ui-job-result-detail-title','tag','div');

cTitle		= neurojobs.parse.extract(detail,'a','type','tag','return','text');
cLink		= neurojobs.parse.extract(detail,'a','type','tag','return','href');
cDate		= neurojobs.parse.extract(div,'bti-ui-job-result-detail-age','return','text');
cPlace		= neurojobs.parse.extract(div,'bti-ui-job-result-detail-location','return','text');
cUniv		= neurojobs.parse.extract(div,'bti-ui-job-result-detail-employer','return','text');

nResult	= numel(cTitle);

s	= repmat(neurojobs.result.blank,[nResult 1]);

for kR=1:nResult
	s(kR).date		= FormatTime(cDate{kR});
	s(kR).title		= cTitle{kR};
	s(kR).location	= [cUniv{kR} ', ' cPlace{kR}];
	s(kR).url		= ['http://neurojobs.sfn.org' cLink{kR}];
end

% url		= 'http://neurojobs.sfn.org/jobs/?display=rss&resultsPerPage=100';
% node	= neurojobs.site.fetch(url);

% item	= neurojobs.parse.extract(node,'item','type','tag');

% cInfo	= neurojobs.parse.extract(item,'title','type','tag','return','text');
% cLink	= neurojobs.parse.extract(item,'guid','type','tag','return','text');
% cDate	= neurojobs.parse.extract(item,'pubDate','type','tag','return','text');

% nResult	= numel(cInfo);

% s	= repmat(neurojobs.result.blank,[nResult 1]);

% for kR=1:nResult
% 	ifo	= regexp(cInfo{kR},'(?<title>.+) \| (?<loc>.+)','names');
	
% 	s(kR).date		= FormatTime(getfield(regexp(cDate{kR},'(?<date>\d+ \w+ \d+ \d+:\d+:\d+)','names'),'date'));
% 	s(kR).title		= ifo.title;
% 	s(kR).location	= ifo.loc;
% 	s(kR).url		= cLink{kR};
% end
