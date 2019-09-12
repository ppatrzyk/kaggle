import time
import os
import numpy as np
import pandas as pd

from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import OneHotEncoder
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import GridSearchCV
from sklearn.metrics import roc_auc_score

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

	rf = RandomForestClassifier(
		n_estimators=100, min_samples_leaf=1,
		min_samples_split=2, min_weight_fraction_leaf=0.0, 
		max_leaf_nodes=None, min_impurity_decrease=0.0, 
		min_impurity_split=None, bootstrap=False, 
		oob_score=False, random_state=None, verbose=0, warm_start=False, 
	)
	param_grid = {
		'criterion': ['gini'],
		'max_depth': [25, 100],
		'max_features': [None, 'sqrt', 100],
		'class_weight': ['balanced']
	}
	rf_search = GridSearchCV(rf, param_grid, cv=3, scoring='roc_auc', verbose=10, n_jobs=-1)
	rf_search.fit(X_train, y_train)
	res = pd.DataFrame.from_dict(rf_search.cv_results_)
	res.to_csv('rf_gridsearch.csv')
