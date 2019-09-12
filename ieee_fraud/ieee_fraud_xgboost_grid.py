import time
import os
import numpy as np
import pandas as pd

from xgboost import XGBClassifier

from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import OneHotEncoder
from sklearn.model_selection import GridSearchCV
from sklearn.metrics import roc_auc_score

from sklearn.model_selection import train_test_split

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

	xgb = XGBClassifier(
		learning_rate=0.1, verbosity=1, objective='binary:logistic',
		n_jobs=1, gamma=0, n_estimators=100,
		min_child_weight=1, max_delta_step=0,
		subsample=1, colsample_bytree=1,
		colsample_bylevel=1, colsample_bynode=1,
		reg_alpha=0, reg_lambda=1, scale_pos_weight=1,
		base_score=0.5, random_state=0
	)
	param_grid = {
		'booster': ['gbtree', 'dart'],
		'max_depth': [3, 10, 50]
	}
	xgb_search = GridSearchCV(xgb, param_grid, cv=3, scoring='roc_auc', verbose=10, n_jobs=-1)
	xgb_search.fit(X_train, y_train)
	res = pd.DataFrame.from_dict(xgb_search.cv_results_)
	res.to_csv('xgboost_gridsearch.csv')
	print(f'end: {round(time.time()-start, 2)} secs from start')
