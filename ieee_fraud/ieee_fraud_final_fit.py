import time
import os
import numpy as np
import pandas as pd

import joblib

from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import OneHotEncoder
from sklearn.metrics import roc_auc_score

from sklearn.tree import DecisionTreeClassifier
from sklearn.ensemble import RandomForestClassifier

from lightgbm import LGBMClassifier
from xgboost import XGBClassifier

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

	# LIGHTGBM
	# [1] "{'boosting_type': 'dart', 'colsample_bytree': 1, 'learning_rate': 0.2, 'num_leaves': 200, 'reg_alpha': 0, 'reg_lambda': 0, 'subsample': 1}"    
	# [2] "{'boosting_type': 'gbdt', 'colsample_bytree': 0.8, 'learning_rate': 0.1, 'num_leaves': 200, 'reg_alpha': 0, 'reg_lambda': 0, 'subsample': 0.8}"
	lgbm_dart = LGBMClassifier(
		boosting_type='dart',
		colsample_bytree=1,
		learning_rate=0.2,
		num_leaves=200,
		reg_alpha=0,
		reg_lambda=0,
		subsample=1,
		n_estimators=500, max_depth=-1,
		subsample_for_bin=200000, objective='binary', 
		class_weight=None, min_split_gain=0.0, 
		min_child_weight=0.001, min_child_samples=20,
		subsample_freq=0, random_state=None, n_jobs=-1, 
		silent=False, importance_type='split'
	)
	lgbm_dart.fit(X_train, y_train)
	joblib.dump(lgbm_dart, 'lgbm_dart.joblib')
	del lgbm_dart

	lgbm_gbdt = LGBMClassifier(
		boosting_type='gbdt',
		colsample_bytree=0.8,
		learning_rate=0.1,
		num_leaves=200,
		reg_alpha=0,
		reg_lambda=0,
		subsample=0.8,
		n_estimators=500, max_depth=-1,
		subsample_for_bin=200000, objective='binary',
		class_weight=None, min_split_gain=0.0, 
		min_child_weight=0.001, min_child_samples=20,
		subsample_freq=0, random_state=None, n_jobs=-1,
		silent=False, importance_type='split'
	)
	lgbm_gbdt.fit(X_train, y_train)
	joblib.dump(lgbm_gbdt, 'lgbm_gbdt.joblib')
	del lgbm_gbdt

	# XGBOOST
	# [1] "{'booster': 'gbtree', 'max_depth': 50}"
	xgb = XGBClassifier(
		booster='gbtree', max_depth=50,
		learning_rate=0.1, verbosity=1, objective='binary:logistic',
		n_jobs=-1, gamma=0, n_estimators=100,
		min_child_weight=1, max_delta_step=0,
		subsample=1, colsample_bytree=1,
		colsample_bylevel=1, colsample_bynode=1,
		reg_alpha=0, reg_lambda=1, scale_pos_weight=1,
		base_score=0.5, random_state=0
	)
	xgb.fit(X_train, y_train)
	joblib.dump(xgb, 'xgboost.joblib')
	del xgb

	# RANDOM FOREST
	# [1] "{'class_weight': 'balanced', 'criterion': 'gini', 'max_depth': 100, 'max_features': 'sqrt'}"
	rf = RandomForestClassifier(
		class_weight='balanced',
		criterion='gini',
		max_depth=100,
		max_features='sqrt',
		n_estimators=100, min_samples_leaf=1,
		min_samples_split=2, min_weight_fraction_leaf=0.0,
		max_leaf_nodes=None, min_impurity_decrease=0.0,
		min_impurity_split=None, bootstrap=False,
		oob_score=False, random_state=None, verbose=10, warm_start=False
	)
	rf.fit(X_train, y_train)
	joblib.dump(rf, 'rf.joblib')
	del rf
