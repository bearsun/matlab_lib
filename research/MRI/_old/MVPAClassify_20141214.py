import warnings

with warnings.catch_warnings():
	warnings.filterwarnings("ignore",category=DeprecationWarning)
	
	import sys
	import os
	import time
	import json
	import random
	
	from abc import ABCMeta, abstractmethod
	
	import numpy as np
	import scipy.io
	import scipy.stats as spstats
	
	from sklearn.metrics.pairwise import pairwise_distances
	from sklearn.utils.linear_assignment_ import linear_assignment
	
	from mvpa2.suite import *

np.seterr(divide='ignore');
np.seterr(invalid='ignore');

#for debugging
DBG_PATH_PARAM = None
DBG_LEVELS = ['all', 'info', 'warn', 'error']
DBG_PREFIX = [None, None, 'warning', 'error']

dbg = 'all'

def rec2dict(rec):
	if isinstance(rec,np.ndarray):
		if rec.shape==(1,1) and isinstance(rec[0,0].dtype.names,tuple):
			d = {}
			
			for key in rec[0,0].dtype.names:
				d[key] = rec2dict(rec[0,0][key])
			
			return d
		elif rec.dtype.str.startswith('<U'):
			if len(rec)==1:
				rec = str(rec[0])
			else:
				raise Exception('damn')
		elif len(rec.shape)==2:
			for (x,y), res in np.ndenumerate(rec):
				rec[x,y] = rec2dict(rec[x,y])
	
	return rec

def force_list(x, count=None):
	"""force x to be a list of the specified size"""
	if not isinstance(x, list):
		x = [x]
	
	if count is not None:
		if x == []:
			x = [None]
		
		x_count = len(x)
		
		if x_count < count:
			x.extend([x[-1]]*(count - x_count))
		elif x_count > count:
			x = x[0:count]
			
	return x

def flip_dict(x):
	"""flip an NxN array of dicts to be a dict of NxN arrays"""
	shp = np.shape(x)
	y = x[0,1].copy()
	
	for key in y:
		val = y[key]
		
		if np.isscalar(val) and not isinstance(val, str):
			dtype = np.float64
		else:
			dtype = np.object
		
		y[key] = np.ndarray(shp, dtype=dtype)
			
		for (i,j), d in np.ndenumerate(x):
			if isinstance(d, dict):
				y[key][i,j] = d[key]
			else:
				y[key][i,j] = np.nan
		
		if isinstance(val, dict):
			y[key] = flip_dict(y[key])
	
	return y

def has_len(x):
	"""test whether a variable has a length"""
	try:
		return len(x)>=0
	except Exception:
		return False

def status(msg, indent=0, debug='info'):
	"""show a status message"""
	global dbg, DBG_LEVELS
	
	dbg_idx = DBG_LEVELS.index(dbg)
	debug_idx = DBG_LEVELS.index(debug)
	
	if debug_idx >= dbg_idx:
		str_indent = '   '*indent
		str_time   = time.strftime('%Y-%m-%d %H:%M:%S')
		
		str_prefix = DBG_PREFIX[debug_idx]
		str_prefix = '%s: ' % (str_prefix)  if str_prefix else ''
		
		print '%s %s- %s%s' % (str_time, str_indent, str_prefix, msg)

def divides(x, d):
	"""does d divide x?"""
	return (x % d) == 0

def notfalse(x):
	"""return True if x is not False"""
	return not isinstance(x,bool) or x!=False

def get_field_name(str):
	"""generate a valid MATLAB field name from str"""
	#convert non-alphanumeric characters to underscores
	str = re.sub(r'[^A-Za-z0-9]+', '_', str)
	#make sure the string starts with a letter
	str = re.sub('^[^A-Za-z]+', '', str);
	#make sure we have something
	if len(str) == 0:
		str = 'X'
	
	return str

def split_path(path, ext_favor=None):
	"""split a path into directory, pre-extension file name, and file
	extension"""
	path_dir, path_file = os.path.split(path)
	
	found_ext = False
	if ext_favor:
		ext_favor = force_list(ext_favor)
		
		#make sure the extensions start with a dot
		for idx in range(len(ext_favor)):
			if not ext_favor[idx].startswith('.'):
				ext_favor[idx] = '.%s' % (ext_favor[idx])
		
		#order the extensions from longest to shortest
		ext_count = [len(ext) for ext in ext_favor]
		ext_sort_idx = [idx[0] for idx in sorted(enumerate(ext_count), key=lambda x:x[1])]
		ext_favor = [ext_favor[idx] for idx in ext_sort_idx]
		
		#search for each extension
		for path_file_ext in ext_favor:
			found_ext = path_file.endswith(path_file_ext)
			if found_ext:
				path_file_pre = path_file[:-len(path_file_ext)]
				break
	
	if not found_ext:
		path_file_pre, path_file_ext = os.path.splitext(path_file)
	
	return path_dir, path_file_pre, path_file_ext

def add_file_suffix(file_path, suffix):
	path_dir,file_pre,file_ext = split_path(file_path)
	
	return os.path.join(path_dir,'%s%s%s' % (file_pre, suffix, file_ext))

def map2nifti_fixed(ds, data=None):
	"""when map2niftiing spatiotemporal datasets, we get extra zero-filled
	samples. also make non-masked values NaN."""
	if data == None:
		data = ds
	data_like = data.samples if isinstance(data, Dataset) else data
	
	#map to nifti
	nii = map2nifti(ds, data=data)
	
	#NaN non-mask values
	msk = map2nifti(ds, data=np.ones_like(data_like, dtype='bool_')).get_data()
	nii._data[~msk] = np.nan
	
	#remove the extra samples
	sample_count = ds.shape[0] if data is None else np.shape(data)[0]
	nii_sample_count = nii.shape[3]
	
	if sample_count != nii_sample_count:
		if divides(nii_sample_count, sample_count):
			idx_step = int(nii_sample_count / sample_count)
			
			nii._data = nii._data[:,:,:,0::idx_step]
		else:
			raise Exception('map2nifti, %d does not divide %d' % (sample_count, nii_sample_count))
	
	
	return nii
	
def save_dataset(param, array_type, ds, data=None):
	nii = map2nifti_fixed(ds, data=data)
	
	if param['array_to_file']:
		path_prefix = os.path.splitext(param['path_result'])[0]
		
		path_suffix = []
		path_suffix.append(array_type)
		path_suffix.append(param['mask_name'])
		
		if param['mask_bootstrap_idx'] is not None:
			path_suffix.append(str(param['mask_bootstrap_idx']))
		
		path_suffix.append(get_field_name(param['classification_name']))
		
		path_out = '%s-%s.nii.gz' % (path_prefix, "-".join(path_suffix))
		
		nii.to_filename(path_out)
		
		return path_out
	else:
		return nii.get_data()


def process_sensitivities(param, ds, sense):
	result = {}
	
	result['raw'] = save_dataset(param, 'sensitivities', ds, data=sense)

	#calculate some stats
	sense = map2nifti_fixed(ds, data=sense).get_data()
	result['mean'] = np.mean(sense, axis=3)
	result['df'] = np.size(sense,axis=3) - 1
	#*df to correct for between-fold similarity
	result['se'] = spstats.sem(sense, axis=3) * result['df']
	result['t'] = result['mean'] / result['se']
	result['p'] = spstats.t.sf(abs(result['t']), result['df'])*2
	
	return result

def parse_twoway(result, key=None):
	"""change the NxN ndarray of dicts to a dict of NxN arrays"""
	if key == 'twoway':
		result = flip_dict(result)
	elif isinstance(result, dict):
		for key in result:
			result[key] = parse_twoway(result[key], key=key)
	
	return result

def average_values(result):
	"""average the results of bootstrapping"""
	result_avg = result[0]
	
	if isinstance(result_avg,dict):
		for key in result_avg:
			val = result_avg[key]
			
			if isinstance(val,dict):
				result_avg[key] = average_values([r[key] for r in result])
			elif isinstance(val, np.float64):
				result_avg[key] = np.nanmean([r[key] for r in result], axis=0)
			elif key == 'twoway':
				for (x,y), res in np.ndenumerate(val):
					result_avg[key][x,y] = average_values([r[key][x,y] for r in result])
			elif isinstance(val, np.ndarray) and not val.dtype == np.object:
				result_avg[key] = np.nanmean([r[key] for r in result], axis=0)
			elif key != 'target':
				result_avg[key] = [r[key] for r in result]
				
				#make sure we get a cell-array back in MATLAB
				if isinstance(val, str):
					result_avg[key] = np.array(result_avg[key],dtype=np.object)
	
	return result_avg

def parse_values(result, key=None):
	"""reformat the results of the classifications"""
	if has_len(result) and len(result) == 0:
		return result
	
	if isinstance(result, dict):  # result dict
		for key in result:
			result[key] = parse_values(result[key], key=key)
	elif isinstance(result, list) and isinstance(result[0],dict):  # bootstrapped results need to be averaged
		result = average_values([parse_values(res) for res in result])
	elif key == 'twoway':  # twoway classifications
		for (x,y), res in np.ndenumerate(result):
			result[x,y] = parse_values(res)
	elif isinstance(result, np.ndarray) and not result.dtype == np.object:  # make everything double precision
		result = result.astype(np.float64)
	
	return result

def acc_stats(accuracies, target_count=None):
	acc = {
		'all': accuracies,
		'mean': np.mean(accuracies),
		'se': np.asscalar(spstats.sem(accuracies))
	}
	
	if target_count is not None:
		#one-tailed binomial test
		N = len(accuracies)
		X = np.round(acc['mean'] * N)
		acc['chance'] = 1.0/target_count
		
		acc['binomial_p'] = spstats.binom.sf(X-1, N, acc['chance'])
	
	return acc

def compute_accuracy_stats(result, target_count=None, key=None):
	"""calculate some statistics for the classification accuracies"""
	if key == 'accuracy' and 'all' in result:
		result = result['all']
		
		if isinstance(result, np.ndarray) and result.dtype == np.object:
			for (x,y), val in np.ndenumerate(result):
				if not np.isscalar(result[x,y]) or not np.isnan(result[x,y]):
					result[x,y] = acc_stats(result[x,y], target_count)
			
			result = flip_dict(result)
		else:
			result = acc_stats(result, target_count)
	elif isinstance(result, dict):
		if 'target' in result:
			if np.ndim(result['target']) == 2 and result['target'].shape[1]!=1:
				target_count = len(result['target'][0,-1])
			else:
				target_count = len(result['target'])
		else:
			target_count = None
			
		for key in result:
			result[key] = compute_accuracy_stats(result[key], target_count=target_count, key=key)
	
	return result

def parse_results(param, result):
	result = parse_values(result)
	result = parse_twoway(result)
	result = compute_accuracy_stats(result)
	
	return result


def feature_match(ds1, ds2, metric='correlation'):
	"""reorder the features of ds2 so they match as closely as possible those
	of ds1. ds1 and ds2 must have the same number of features.
	
	Parameters
	----------
	ds1 : Dataset
	  a dataset
	ds2 : Dataset
	  a dataset with the same number of features as ds1
	metric : str, optional
	  the distance metric to use (see sklearn's pairwise_distances)
	
	Returns
	-------
	idx : array
	  the index array used to reorder the features of ds2
	"""
	
	#calculate the pairwise distance between each feature
	D = pairwise_distances(np.transpose(ds1),np.transpose(ds2),metric='correlation')
	
	#make negative correlations positive, and mark them for negating if they
	#end up being matches
	if metric=='correlation':
		negate = D > 1
		D[negate] = 2 - D[negate]  # 1 - (-(1 - D))
		
		#anything negative now is just due to floating point error
		D[D<0] = 0
	else:
		negate = np.ones(D.shape, dtype=bool)
	
	#minimize the trace in order to find a matching of features that
	#minimizes matched feature distances
	rc_idx = linear_assignment(D)
	idx = rc_idx[:,1]
	
	#add a feature attribute to keep track of the original indices
	ds2.fa['idx_orig'] = np.arange(0,ds2.nfeatures)
	
	#reorder the features of ds2
	ds2.samples = ds2.samples[:,idx]
	
	#reorder the feature attributes as well
	for attr in ds2.fa.values():
		ds2.fa[attr.name].value = attr.value[idx]
	
	#negate the components with negative correlations
	if metric=='correlation':
		negate = negate[:,idx]
		diag = np.eye(ds2.nfeatures, dtype=bool)
		negate = negate[diag]
		
		#add a feature attribute to keep track of which features were
		#negated
		ds2.fa['negated'] = negate
		
		ds2.samples[:, negate]	 = -ds2.samples[:, negate]
	
	return idx

class Locker(object):
	"""object to prevent other processes from doing something until we are
	finished"""
	_interval = 0.5
	_timeout = 3
	
	_pair_id = None
	
	path = {}
	
	name = None
	paired = False
	duration = None
	
	@property
	def age(self):
		"""age of the lock file, in seconds"""
		try:
			return time.time() - os.path.getmtime(self.path['lock'])
		except Exception:
			return np.inf
	
	def wait(self):
		"""wait until the lock file is gone or times out"""
		while self._locked() and self.age < self._timeout:
			self._sleep()
		
	def start(self):
		"""start the lock"""
		start_time = time.time()
		
		while self._continue() and time.time() - start_time < self.duration:
			self._touch('lock')
			self._sleep()
		
		self._clear()
		
	def stop(self):
		"""stop the lock"""
		self._touch('stop')
	
	def __init__(self, name, paired=False, duration=np.inf, pair_id=None):
		self.name = name
		self.paired = paired
		self.duration = duration
		
		if self.paired:
			self._pair_id = pair_id if pair_id is not None else int(time.time()*1000000)
		
		self.path['lock'] = self._get_path('lock')
		self.path['stop'] = self._get_path('stop', paired=True)
	
	def _get_path(self, name, paired=False):
		"""get the path to a signal file"""
		if paired and self.paired:
			pre = '%s%d' % (self.name, self._pair_id)
		else:
			pre = self.name			
		
		return os.path.join('/tmp','%s.%s' % (pre, name))
	
	def _exists(self, name):
		"""does a file exist?"""
		return os.path.exists(self.path[name])
	
	def _touch(self, name):
		"""update a file's modification time"""
		with file(self.path[name],'a'):
			os.utime(self.path[name],None)
	
	def _remove(self, name):
		"""remove a file"""
		if self._exists(name):
			try:
				os.remove(self.path[name])
			except Exception:
				pass

	def _locked(self):
		"""are we locked"""
		return self._exists('lock')
	
	def _continue(self):
		"""should we continue locking?"""
		return not self._exists('stop')
	
	def _clear(self):
		"""clear all the files"""
		for name in self.path:
			self._remove(name)
	
	def _sleep(self):
		"""wait a bit"""
		time.sleep(self._interval)


class Parameters(dict):
	"""dict-like object that stores parameters loaded in from the parameter file"""
	path = None
	
	def __init__(self, path=None, *args, **kwargs):
		dict.__init__(self, *args, **kwargs)
		
		self.load(path)
	
	def __getitem__(self, key):
		if key in self:
			return dict.__getitem__(self, key)
		else:
			raise KeyError("parameter '%s' is undefined." % key)
	
	def load(self, path=None):
		"""load the parameters from file"""
		self.path = path
		
		#look for a script input argument if we don't have a path
		if self.path is None:
			assert len(sys.argv) > 1, "This script must be passed the path to the parameter file."
			self.path = sys.argv[1]
		
		assert os.path.exists(self.path), "Parameter file '%s' does not exist." % self.path
		
		status('loading parameters from %s' % (self.path), debug='all')
		with open(self.path,'r') as f:
			param = json.load(f)
		
		self.update(param)
		self.parse()
	
	def parse(self):
		"""parse some parameter values"""
		global dbg
		
		#clean up the parameters
		self.clean_parameter(self)
		
		dbg = self['debug']
		
		#make sure these are all lists
		self['path_mask']        = force_list(self['path_mask'])
		self['mask_name']        = force_list(self['mask_name'], len(self['path_mask']))
		self['target_subset']    = force_list(self['target_subset'])
		self['classifier']       = force_list(self['classifier'])
		
		#make sure each mask has a name
		for idx in range(len(self['path_mask'])):
			if not self['mask_name'][idx]:
				mask_file_pre = split_path(self['path_mask'][idx], ext_favor='nii.gz')[1]
				self['mask_name'][idx] = get_field_name(mask_file_pre)
		
		#the subset of targets to analyze
		set_target = set(self['target_subset'])
		if self['target_blank']:
			set_blank = set(force_list(self['target_blank']))
			set_target = set_target.difference(set_blank)
		self['target_subset'] = list(set_target)
		
		#parse the partitioner
		if isinstance(self['partitioner'], int):
			self['partitioner'] = NFoldPartitioner(cvtype=self['partitioner'])
		elif isinstance(self['partitioner'], str):
			self['partitioner'] = eval(self['partitioner'])
		else:
			raise Exception('Unrecognized partitioner parameter.')
			
		
		#construct the classifiers. make sure we have () at the end.
		self['classifier'] = [eval(re.sub(r'([^\)])$',r'\1()',clf)) for clf in self['classifier']]
		
		#do some error checking
		if len(self['classifier']) > 1 and self['sensitivities']:
			raise Exception('Sensitivities cannot be saved if more than one classifier is specified.')
	
	@classmethod
	def clean_parameter(cls, x):
		"""clean up parameter values so they play nice with pymvpa"""
		if isinstance(x,list):
			x = [cls.clean_parameter(y) for y in x]
		elif isinstance(x,dict):
			for key in x:
				x[key] = cls.clean_parameter(x[key])
		elif isinstance(x, unicode):  # pymvpa doesn't like unicode strings
			x = str(x)
		
		return x


class FileObject(object):
	__metaclass__ = ABCMeta	
	
	param = None
	args = []
	kwargs = {}
	
	obj = None
	
	def load(self):	
		self.obj = self._loader(*self.args, **self.kwargs)
	
	def __init__(self, param, *args, **kwargs):
		self.param = param
		self.args = args
		self.kwargs = kwargs
	
	def __call__(self):
		if self.obj is None:
			self.load()
		
		return self.obj
	
	@abstractmethod
	def _loader(self, *args, **kwargs):
		pass
	

class Mask(FileObject):
	name = None
	
	def __init__(self, param, idx):
		FileObject.__init__(self, param, idx)
		
		self.name = self.param['mask_name'][idx]
	
	def _loader(self, idx):
		"""load a single mask"""
		path_mask = self.param['path_mask'][idx]
		
		status('loading mask: %s' % (self.name), indent=1, debug='all')
	
		#load the mask
		mask = fmri_dataset(path_mask)
		
		#make it boolean
		mask.samples = mask.samples != 0
		
		#set some attributes
		mask.a['name'] = self.name
		mask.a['idx'] = np.nonzero(mask)[1]
		mask.a['size'] = len(mask.a.idx)
		
		return mask

class Masks(dict):
	"""container for the masks that will be used in the classification"""
	param = None
	
	def __init__(self, param, *args, **kwargs):
		dict.__init__(self, *args, **kwargs)
		
		self.param = param
		
		if param['path_mask']:
			for idx in range(len(param['path_mask'])):
				mask_name = self.param['mask_name'][idx]
				self[mask_name] = Mask(param, idx)
			
			if param['mask_balancer']=='bootstrap':
				param['mask_size_min'] = min([self[mask]().a.size for mask in self])

class Data(FileObject):
	"""classification data"""
	def _loader(self):
		status('loading data')
		
		#data parameters
		samples = self.param['path_data']
		attr = SampleAttributes(param['path_attribute'])
		
		#lock object to make sure only one process loads data at a time
		lock = Locker(name='mvpaclassify_load_data', paired=True, duration=300)
		
		#wait until the lock is free
		lock.wait()
		
		#fork a child process that will maintain the lock until the data are
		#loaded
		pid = os.fork()
		if pid:  # parent
			#load the data
			ds = fmri_dataset(samples=samples, chunks=attr.chunks, targets=attr.targets)
			
			#stop the lock
			lock.stop()
		else:  # child
			#lock the process
			lock.start()
			
			os._exit(0)
		
		#add the custom sample attributes
		if isinstance(param['sample_attr'],dict):
			for key in param['sample_attr']:
				ds.sa[str(key)] = param['sample_attr'][key]
		
		return ds


class Result(dict):
	param = None
	
	output_path = None
	
	def exists(self):
		return os.path.exists(self.output_path)
	
	def save(self, indent=0):
		"""save the results to a MATLAB .mat file"""
		status('saving results to %s' % (self.output_path), indent=indent, debug='all')
		scipy.io.savemat(
			self.output_path,
			{'result': self},
			oned_as='column',
			do_compression=True
		)
	
	def load(self):
		"""load existing results"""
		status('loading results from %s' % (self.output_path), debug='all')
		
		result = rec2dict(scipy.io.loadmat(self.output_path)['result'])
		
		for key in result:
			self[key] = result[key]
	
	def __init__(self, param, mask=None, *args, **kwargs):
		dict.__init__(self, *args, **kwargs)
		
		self.param = param
		
		self.output_path = self.param['path_result']
		
		if mask:
			mask_suffix = '-%s' % (mask.name)
			self.output_path = add_file_suffix(self.output_path, mask_suffix)


class NCTrainingStats(dict):
	"""dict-like object to store the chosen NestedClassifier classifier while
	working well with the way pymvpa handles training stats"""
	def __iadd__(self, value):
		if isinstance(value, NCTrainingStats):
			for key in value:
				if key in self:
					self[key].__iadd__(value[key])
				else:
					self[key] = value[key]
		elif 'confusion' in self:
			self['confusion'] = self['confusion'].__iadd__([value])
		else:
			self['confusion'] = [value]


class CrossClassifier(ProxyClassifier):
	"""Classifier that will train itself on one dataset and test itself on
	another. In order for this to work, data from the two datasets must be
	concatenated into a single dataset which includes a sample attribute to
	distinguish between the two original datasets."""
	__clf2 = None
	
	__dataset_attr = None
	
	__match_features = False
	__feature_match_idx = None
	__feature_match_negate = None
	
	def __init__(self, clf, dataset_attr='dataset', match_features=False, *args, **kwargs):
		"""Initialize the instance of CrossClassifier
		
		Parameters
		----------
		clf : Classifier
		  the classifier to use
		dataset_attr : str
		  the name of the sample attribute that identifies to which of the
		  two combined datasets each sample belongs
		match_features : bool, optional
		  match the feature spaces of the two datasets while training and
		  apply the new feature space order to the testing data before
		  predicting. matching is done by maximizing the correlation
		  between paired features.
		"""
		self.__clf2 = copy.deepcopy(clf)
		
		ProxyClassifier.__init__(self, clf, *args, **kwargs)
				
		clf.ca = copy.deepcopy(self.ca)
		self.__clf2.ca = copy.deepcopy(self.ca)
		
		self.__dataset_attr = dataset_attr
		self.__match_features = match_features
	
	def _set_retrainable(self, value, force=False):
		self.__clf2._set_retrainable(value, force=force)
		super(CrossClassifier, self)._set_retrainable(value, force=force)		
		
	def _train(self, dataset):
		attr = dataset.sa[self.__dataset_attr].value
		
		ds1 = dataset[attr==1]
		ds2 = dataset[attr==2]
		
		#match the features between ds1 and ds2
		if self.__match_features:
			self.__feature_match_idx = feature_match(ds1, ds2)
			self.__feature_match_negate = ds2.fa.negated
		
		super(CrossClassifier, self)._train(ds1)
		self.__clf2.train(ds2)
	
	def _predict(self, dataset):
		attr = dataset.sa[self.__dataset_attr].value
		
		ds1 = dataset[attr==1]
		ds2 = dataset[attr==2]
		
		#apply the feature order determined during training
		if self.__match_features:
			ds2 = ds2[:,self.__feature_match_idx]
			ds2.samples[:,self.__feature_match_negate] = -ds2.samples[:,self.__feature_match_negate]
		
		#use the classifier trained on ds1 to predict ds2
		result2 = super(CrossClassifier, self)._predict(ds2)
		
		#use the classifier trained on ds2 to predict ds1
		clf = self.__clf2
		if self.ca.is_enabled('estimates'):
			clf.ca.enable(['estimates'])
		result1 = clf.predict(ds1)
		
		#update the estimates to reflect both predictions
		estimates1 = copy.deepcopy(clf.ca.get('estimates', None).value)
		estimates2 = copy.deepcopy(self.ca.get('estimates', None).value)
		estimates = [estimates1.pop(0) if idx==1 else estimates2.pop(0) for idx in attr]
		self.ca['estimates'].value = estimates
		
		return [result1.pop(0) if idx==1 else result2.pop(0) for idx in attr]
	
	def _untrain(self):
		if not self.__clf2 is None:
			self.__clf2.untrain()
												
		super(CrossClassifier, self)._untrain()


class NestedClassifier(Classifier):
	"""nested classifier that uses its own internal cross validation to
	choose the best of a set of classifiers on each fold"""
	clfs = []
	best_clf_idx = None
	
	partitioner = None
	
	def __init__(self, clfs, partitioner, *args, **kwargs):
		Classifier.__init__(self, *args, **kwargs)
		
		self.clfs = clfs if isinstance(clfs,list) else [clfs]
		
		for clf in self.clfs:
			clf.ca = self.ca
		
		self.partitioner = partitioner
	
	def __CV(self, clf, ds):
		"""perform cross-validation to determine how well the given
		classifier performs with the given dataset"""
		#status('testing %s' % (clf), indent=1, debug='all')
		
		#classify
		cv = CrossValidation(clf,self.partitioner)
		res = cv(ds)
		
		#return the average error across folds
		return np.mean(res.samples)
	
	def _train(self, ds):
		#status('training', debug='all')
		
		#find the best classifier for this dataset
		err = [self.__CV(clf, ds) for clf in self.clfs]
		self.best_clf_idx = np.where(err == min(err))[0][0]
		
		#status('chose %s' % (self.clfs[self.best_clf_idx]), indent=1, debug='all')
		
		#use it to train on the full dataset
		
		return self.clfs[self.best_clf_idx].train(ds)
	
	def _posttrain(self, ds):
		"""save a record of the chosen classifier"""
		Classifier._posttrain(self, ds)
		
		if self.ca.is_enabled('training_stats'):
			self.ca.training_stats = NCTrainingStats(
				confusion=self.ca.training_stats,
				classifier=[self.best_clf_idx],
				)
	
	def _predict(self, ds):
		return self.clfs[self.best_clf_idx].predict(ds)


class CaptureSelector(ElementSelector):
	"""feature selector that keeps a record of what was selected"""
	param = None
	selector = None
	
	selection_count = 0
	selected = None
	
	def reset(self):
		"""empty the selected array"""
		self.selected.samples[:] = 0
		self.selection_count = 0
		
	def save(self, mask=None, indent=0):
		"""save the selected voxels"""
		self.selected.samples /= self.selection_count
		selected = save_dataset(self.param, 'selected', self.selected)
		
		self.reset()
		
		return selected
	
	def __init__(self, param, ds, selector, *args, **kwargs):
		ElementSelector.__init__(self, *args, **kwargs)
		
		self.param = param
		self.selector = selector
		self.selected = ds[0].copy()
		
		self.reset()
	
	def _call(self, seq):
		#call the actual selector
		selected = self.selector(seq)
		
		#save a record of what was selected
		self.selected.samples[0,selected] += 1
		self.selection_count += 1
		
		return selected

	
def preprocess_data(param, ds):
	"""preprocess a set of data"""
	#remove NaNs
	if param['nan_remove'].startswith('sample'):
		status('removing NaNs by sample', indent=1, debug='all')
		ds = ds[~np.any(np.isnan(ds),1),:]
	elif param['nan_remove'].startswith('feature'):
		status('removing NaNs by feature', indent=1, debug='all')
		ds = ds[:,~np.any(np.isnan(ds),0)]
	
	#zscore the data
	if param['zscore']:
		status('z-scoring samples', indent=1)
		
		#use a custom attribute to determine groups for z-scoring
		if isinstance(param['zscore'], str):
			zscore_attr = param['zscore']
		else:
			status('using custom zscore attribute', indent=2, debug='all')
			ds.sa['zscore'] = param['zscore']
			
			zscore_attr = 'zscore'
		
		zscore(ds, chunks_attr=zscore_attr)
	
	#create a spatiotemporal event-related dataset
	if param['spatiotemporal']:
		status('constructing spatiotemporal dataset', indent=1)
		
		events = find_events(targets=ds.sa.targets, chunks=ds.sa.chunks)
		
		#keep only the events we are interested in
		events = [ ev for ev in events if ev['targets'] in param['target_subset'] ]
		
		ds = eventrelated_dataset(ds, events=events)
		
		#fix the custom sample attributes
		for key in param['sample_attr']:
			ds.sa[key] = [x[0] for x in ds.sa[key]]
	
	#keep only the targets we are interested in
	status('including targets: %s' % (", ".join(param['target_subset'])), indent=1, debug='all')
	ds = ds[array([ trg in param['target_subset'] for trg in ds.sa.targets ])]
	
	#average samples within each chunk
	if param['average']:
		status('averaging samples within each chunk', indent=1)
		
		avg = mean_group_sample(['targets','chunks'])
		ds  = ds.get_mapped(avg)
	
	#make sure we should actually do target balancing
	param['do_target_balancer'] = False
	if notfalse(param['target_balancer']):
		#check whether each chunk's complement has the same number of each target
		for chunk in ds.uniquechunks:
			#get the number of each target in the complement
			chunk_targets = list(ds.targets[ds.chunks != chunk])
			target_count = [chunk_targets.count(trg) for trg in ds.uniquetargets]
		
			#make sure the complement has all the targets
			target_zero = np.array(target_count) == 0
			if np.any(target_zero):
				raise Exception("The following target(s) are not in chunk %d's complement: %s" %
					(chunk, ", ".join(list(ds.uniquetargets[target_zero]))))
			
			#unequal numbers of targets, so yep
			if len(np.unique(target_count)) != 1:
				status("unbalanced targets in chunk %d's complement, using target balancer" % (chunk), indent=1, debug='all')
				param['do_target_balancer'] = True
				break
		
		#do one last quick and dirty check to see if targets are unbalanced
		#across the whole dataset
		if not param['do_target_balancer'] and isinstance(param['partitioner'],NFoldPartitioner) and param['partitioner'].cvtype > 1:
			target_count = [ds.targets.count(trg) for trg in ds.uniquetargets]
			if len(np.unique(target_count)) != 1:
				status('unbalanced targets, using target balancer', indent=1, debug='all')
				param['do_target_balancer'] = True
		
		if not param['do_target_balancer']:
			status('target balancer selected but not needed', indent=1, debug='all')
	else:
		status('target balancer not selected', indent=1, debug='all')
	
	return ds

def get_mask_subset(mask, subset_count):
	"""randomly choose a subset of voxels in a mask"""
	mask = mask.copy()
	
	mask.a['idx'] = random.sample(mask.a.idx, subset_count)
	mask.a['size'] = len(mask.a.idx)
	
	mask.samples[:] = False
	mask.samples[:,mask.a.idx] = True
	
	return mask

def get_current_mask(param, result, mask, bootstrap=None):
	"""get either the whole mask or a random subset if we are bootstrapping"""
	if bootstrap is not None:
		mask = get_mask_subset(mask,param['mask_size_min'])
		result['mask_bootstrap_subset'] = mask.a.idx
	
	return mask


def get_partitioner(param, indent=0):
	"""construct the partitioner"""
	partitioner = param['partitioner']
	
	status('base partitioner: %s' % (partitioner.__repr__()), indent=indent, debug='all')
	
	#balancer in case we have an unequal number of target instances
	if param['do_target_balancer']:
		status('using target balancer with %d iterations' % (param['target_balancer']), indent=indent+1, debug='all')
		balancer = Balancer(
					attr='targets',
					count=param['target_balancer'],
					limit='partitions',
					apply_selection=True
					)
		partitioner = ChainNode([partitioner,balancer],space='partitions')
	
	return partitioner

def get_classifier(param, ds, partitioner, mean_control, indent=0):
	"""construct the classifier"""
	#the list of classifiers
	clf = param['classifier']
	
	status('base classifier(s): %s' % (",".join([c.__repr__() for c in clf])), indent=indent, debug='all')
	
	#use a nested classifier if more than one classifier was specified
	param['nested_clf'] = len(clf) > 1
	if param['nested_clf']:
		status('using nested classifier', indent=indent+1, debug='all')
		clf = NestedClassifier(clf, partitioner)
		
		nested_ca = clf.ca
	else:
		clf = clf[0]
	
	#mean control classifier
	if mean_control:
		status('mean mapped classifier', indent=indent+1, debug='all')
		ds.fa['all'] = [1]*len(ds.fa['voxel_indices'])
		clf = MappedClassifier(clf,mean_group_feature(['all'])	)
		
		if param['nested_clf']:
			clf.ca = nested_ca
	
	#feature selection
	if param['selection'] != 1:
		status('feature selection classifier', indent=indent+1, debug='all')
		
		#get the actual selector
		if param['selection'] < 1:
			status('fraction selector (%f)' % (param['selection']), indent=indent+2, debug='all')
			selector_fcn = FractionTailSelector
		else:
			status('fixed n selector (%d)' % (param['selection']), indent=indent+2, debug='all')
			selector_fcn = FixedNElementTailSelector
		selector = selector_fcn(
					param['selection'],
					mode='select',
					tail='upper'
					)
		
		#use a CaptureSelector if we want a record of what was selected
		if param['save_selected']:
			status('capture selector', indent=indent+2, debug='all')
			selector = CaptureSelector(param, ds, selector)
		
		#construct the feature selection classifier
		fsel = SensitivityBasedFeatureSelection(
				OneWayAnova(enable_ca=['raw_results']),
				selector,enable_ca=['sensitivity']
				)
		clf = FeatureSelectionClassifier(clf, fsel)
		
		if param['nested_clf']:
			clf.ca = nested_ca
	else:
		param['save_selected'] = False
	
	return clf

def get_cross_validator(param, clf, partitioner, indent=0):
	"""construct the CrossValidation object"""
	#base keyword arguments for the cross validator
	cv_kwargs = {
		'errorfx':   lambda p,t: np.mean(p == t),
		'enable_ca': ['stats'],
	}
	
	#the NestedClassifier's training stats tell us what clfs were used
	if param['nested_clf']:
		cv_kwargs['enable_ca'].append('training_stats')
	
	#enable permutation testing if specified
	if notfalse(param['permutations']):
		status('enabling statistics with %d permutations' % (param['permutations']), indent=indent, debug='all')
		
		cv_kwargs['postproc'] = mean_sample()
		
		repeater = Repeater(count=param['permutations'])
		permutator = AttributePermutator(
					'targets',
					limit={'partitions': 1},
					count=1
					)
		
		null_partitioner = ChainNode(
						[partitioner, permutator],
						space=partitioner.get_space()
						)
		
		null_cv = CrossValidation(
				clf,
				null_partitioner,
				errorfx=cv_kwargs['errorfx'],
				postproc=cv_kwargs['postproc']
				)
		
		distr_est = MCNullDist(repeater, tail='right', measure=null_cv)
		
		cv_kwargs['null_dist'] = distr_est	
	
	return CrossValidation(clf, partitioner, **cv_kwargs)

def get_targets(ds):
	"""get an np.object array of the target names (so it ends up as a cell)"""
	return ds.uniquetargets.astype(np.object)

def get_classification_results(param, ds, res, cv, mean_control, indent=0):
	"""save some results from the classification"""
	result = {
		'target':		get_targets(ds),
		'accuracy':		{'all': res.samples},
		'confusion'	:	cv.ca.stats.matrix,
	}
	
	status('mean accuracy: %.2f%%' % (100*np.mean(result['accuracy']['all'])), indent=indent)
	
	#selected classifiers (MATLAB, remember these will be 0-based)
	if param['nested_clf']:
		result['classifier'] = cv.ca.training_stats['classifier']
		status('classifiers selected: %s' % (result['classifier']), indent=indent, debug='all')
	
	#save selected voxels
	if param['save_selected'] and not mean_control:
		selector = cv.learner.mapper._SensitivityBasedFeatureSelection__feature_selector
		result['selected'] = selector.save(indent=indent)
	
	#save the sensitivities
	if param['sensitivities'] and not mean_control:
		status('computing sensitivities', indent=indent, debug='all')
		
		clf = cv.learner
		partitioner = cv.generator
		
		sa = RepeatedMeasure(clf.get_sensitivity_analyzer(postproc=maxofabs_sample()),partitioner)
		
		sense = sa(ds)
		if not np.all(sense == 0):
			sense = l1_normed(sense)
		
		status('sensitivities - min:%f, max:%f' % (np.min(sense), np.max(sense)), indent=indent+1, debug='all')
		result['sensitivities'] = process_sensitivities(param, ds, sense)
	
	#save results of permutation test
	if notfalse(param['permutations']):
		result['accuracy']['mean'] = np.mean(result['accuracy']['all'])
		result['accuracy'].pop('all')
		
		result['accuracy']['permutation_p'] = np.mean(cv.ca.null_prob.samples)
	
	return result
	

def classify_one(param, ds, name, mean_control=False, indent=0):
	"""perform a single classification"""
	param['classification_name'] = name
	
	if mean_control:
		status('performing mean control classification', indent=indent)
	else:
		status('performing %s classification' % (name), indent=indent)
	
	#construct the classification objects
	partitioner = get_partitioner(param, indent=indent+1)
	clf = get_classifier(param, ds, partitioner, mean_control, indent=indent+1)
	cv = get_cross_validator(param, clf, partitioner, indent=indent+1)
	
	#do the classification
	status('classifying %s - min:%f, max:%f' % (str(ds.shape), np.min(ds.samples), np.max(ds.samples)), indent=indent+1, debug='all')
	#status('%s' % (ds.targets), indent=indent+1, debug='all')
	res = cv(ds)
	
	#get the results
	result = get_classification_results(param, ds, res, cv, mean_control, indent=indent+1)
	
	#perform a control classification on just the mean of each sample
	if not mean_control and param['mean_control']:
		result['mean_control'] = classify_one(param, ds, name, mean_control=True, indent=indent+1)
	
	return result

def classify_mask(param, data, mask=None, mask_bootstrap_idx=None, indent=0):
	"""perform the classification for a single mask"""
	result = Result(param, mask=mask)
	
	#should we actually do the analysis?
	if not param['force_each'] and result.exists():
		result.load()
		return result
	else:
		status("%s doesn't exist." % (result.output_path), indent=indent, debug='all')
	
	ds = data()
	mask = mask() if mask else mask
	
	param['mask_name'] = mask.a.name if mask else None
	param['mask_bootstrap_idx'] = mask_bootstrap_idx
			
	if mask:
		if mask_bootstrap_idx is None:
			status('classifying: %s' % (param['mask_name']), indent=indent)
		else:
			status('classifying mask bootstrap %d' % (mask_bootstrap_idx), indent=indent, debug='all')
		
		#bootstrap through a set of mask subsets
		if mask_bootstrap_idx is None:
			do_mask_bootstrap = param['mask_balancer']=='bootstrap'
			
			if do_mask_bootstrap:
				mask_size_min = mask.a.size == param['mask_size_min']
				
				if not mask_size_min:
					status('mask bootstrap selected and needed', indent=indent+1, debug='all')
					
					bootstrap_count = param['mask_balancer_count']
					return [classify_mask(
							param,
							ds,
							mask,
							mask_bootstrap_idx=bs,
							indent=indent+1
							) for bs in range(bootstrap_count)]
				else: status('mask bootstrap selected but not needed', indent=indent+1, debug='all')
			else: status('mask bootstrap not selected', indent=indent+1, debug='all')
		
		#get the current mask subset
		mask = get_current_mask(param, result, mask, bootstrap=mask_bootstrap_idx)
			
		#apply the mask
		ds = ds[:,mask.samples[0]]
	else:
		status('classifying', indent=indent)
	
	#preprocess the data
	ds = preprocess_data(param, ds)
	
	#allway classification
	if param['allway']:
		result['allway'] = classify_one(param, ds, 'allway', indent=indent+1)
	
	#every two-way classification
	if param['twoway']:
		target_count = len(ds.uniquetargets)
		
		result['twoway'] = np.zeros((target_count, target_count), dtype=np.object)
		
		for t1 in range(0,target_count):
			for t2 in range(t1+1,target_count):
				#data subset only including the two current targets
				target_sub = ds.uniquetargets[[t1,t2]]
				ds_sub     = ds[np.logical_or(*[ds.targets==trg for trg in target_sub])]
				
				name = 'twoway: %s' % " vs ".join(target_sub)
				result['twoway'][t1,t2] = classify_one(param, ds_sub, name, indent=indent+1)
	
	#save the mask result
	result.save(indent=1)
	
	return result

def classify(param, data, masks):
	"""perform the classification"""
	if masks: # ROI classification
		result = Result(param)
		
		for mask in masks:
			result[mask] = classify_mask(param, data, masks[mask])
	else:  # whole-dataset classification
		result = classify_mask(param, data)
	
	result = parse_results(param, result)
	
	result.save()
	
	return result

#read the parameters file
param = Parameters(path=DBG_PATH_PARAM)

status('commence script execution!', debug='all')

#get the data and masks objects
data = Data(param)
masks = Masks(param)

#classify!
result = classify(param, data, masks)

status('script execution finished!', debug='all')
