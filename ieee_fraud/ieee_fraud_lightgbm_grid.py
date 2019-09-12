import time
import os
import numpy as np
import pandas as pd

from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import OneHotEncoder
from sklearn.model_selection import GridSearchCV
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_auc_score

from lightgbm import LGBMClassifier

if __name__ == '__main__':
	start = time.time()
	train = pd.read_csv("train_clean.csv", sep=",")
	print(f'read data: {round(time.time()-start, 2)} secs from start')
	train.drop(['TransactionID'], axis=1, inplace=True)
	train = train.reindex(np.random.permutation(train.index))

	dummy = []
	dummy.extend([f'id_{i}' for i in range(12, 39)])
	dummy.extend([f'M{i}' for i in range(1, 10)])
	dummy.extend([f'card{i}' for i in range(1, 7)])
	dummy.extend([
		'DeviceType', 'DeviceInfo',
		'P_emaildomain', 'R_emaildomain',
		'ProductCD', 'addr1', 'addr2',
		'afterdot_len', 'wday'
	])

	y_train = train['isFraud'].values
	train.drop('isFraud', axis=1, inplace=True)
	dummy_indices = [i for i, col in enumerate(list(train)) if col in dummy]
	ct = ColumnTransformer(
		transformers=[('one_hot', OneHotEncoder(sparse=True), dummy_indices)],
		remainder='passthrough'
	)
	X_train = ct.fit_transform(train.values)
	del train
	print(f'transformed and splitted: {round(time.time()-start, 2)} secs from start')
	
	lgb = LGBMClassifier(
		n_estimators=500, max_depth=-1,
		subsample_for_bin=200000, objective='binary', 
		class_weight=None, min_split_gain=0.0, 
		min_child_weight=0.001, min_child_samples=20,
		subsample_freq=0, random_state=None, n_jobs=-1, 
		silent=False, importance_type='split'
	)
	param_grid = {
		'boosting_type': ['gbdt', 'dart'],
		'learning_rate': [0.1, 0.2],
		'num_leaves': [100, 200],
		'reg_alpha': [0, 0.2, 0.4],
		'reg_lambda': [0, 0.2, 0.4],
		'subsample': [0.8, 1],
		'colsample_bytree': [0.8, 1]
	}
	lgb_search = GridSearchCV(lgb, param_grid, cv=3, scoring='roc_auc', verbose=10, n_jobs=-1)
	lgb_search.fit(X_train, y_train)
	res = pd.DataFrame.from_dict(lgb_search.cv_results_)
	res.to_csv('lightgbm_gridsearch.csv')
	print(f'end: {round(time.time()-start, 2)} secs from start')
