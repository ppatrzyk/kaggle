import time
import os
import numpy as np
import pandas as pd

import joblib

from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import OneHotEncoder

if __name__ == '__main__':
	start = time.time()
	train = pd.read_csv("train_clean.csv", sep=",")
	test = pd.read_csv("test_clean.csv", sep=",")
	print(f'read data: {round(time.time()-start, 2)} secs from start')

	trans_id = test['TransactionID'].values
	test.drop(['TransactionID'], axis=1, inplace=True)

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
	dummy_indices = [i for i, col in enumerate(list(test)) if col in dummy]
	categories = [sorted(list(set(train[col].values))) for col in list(test) if col in dummy]
	ct = ColumnTransformer(
		transformers=[(
			'one_hot',
			OneHotEncoder(sparse=True, categories=categories, handle_unknown='ignore'),
			dummy_indices
		)],
		remainder='passthrough'
	)
	X_test = ct.fit_transform(test.values)
	del train, test
	print(f'transformed and splitted: {round(time.time()-start, 2)} secs from start')

	lgbm_dart = joblib.load('lgbm_dart.joblib')
	lgbm_dart_probs = lgbm_dart.predict_proba(X_test)[:,1]
	lgbm_dart_submit = pd.DataFrame({
		'TransactionID': trans_id,
		'isFraud': lgbm_dart_probs
	})
	lgbm_dart_submit.to_csv('lgbm_dart_submit.csv', index=False, header=True)
	print(f'lgbm_dart processed: {round(time.time()-start, 2)} secs from start')

	lgbm_gbdt = joblib.load('lgbm_gbdt.joblib')
	lgbm_gbdt_probs = lgbm_gbdt.predict_proba(X_test)[:,1]
	lgbm_gbdt_submit = pd.DataFrame({
		'TransactionID': trans_id,
		'isFraud': lgbm_gbdt_probs
	})
	lgbm_gbdt_submit.to_csv('lgbm_gbdt_submit.csv', index=False, header=True)
	print(f'lgbm_gbdt processed: {round(time.time()-start, 2)} secs from start')

	xgb = joblib.load('xgboost.joblib')
	xgb_probs = xgb.predict_proba(X_test)[:,1]
	xgb_submit = pd.DataFrame({
		'TransactionID': trans_id,
		'isFraud': xgb_probs
	})
	xgb_submit.to_csv('xgb_submit.csv', index=False, header=True)
	print(f'xgb processed: {round(time.time()-start, 2)} secs from start')

	rf = joblib.load('rf.joblib')
	rf_probs = rf.predict_proba(X_test)[:,1]
	rf_submit = pd.DataFrame({
		'TransactionID': trans_id,
		'isFraud': rf_probs
	})
	rf_submit.to_csv('rf_submit.csv', index=False, header=True)
	print(f'rf processed: {round(time.time()-start, 2)} secs from start')
