
import time
import math
import pandas as pd
from lightgbm import LGBMRegressor
from read_data import read_train, read_test

if __name__ == "__main__":

	start = time.time()
	X_train, y_train = read_train()
	print(f'train read: {round(time.time()-start, 2)} secs from start')

	lgbm = LGBMRegressor(
		boosting_type='gbdt', num_leaves=40,
		max_depth=-1, learning_rate=0.5, n_estimators=5000,
		subsample_for_bin=10**6, objective='regression', class_weight=None,
		min_split_gain=0.0, min_child_weight=0.001, min_child_samples=20,
		subsample=0.5, subsample_freq=0, colsample_bytree=1.0,
		reg_alpha=0.01, reg_lambda=0.01, random_state=None,
		n_jobs=-1, silent=True, importance_type='split'
	)
	lgbm.fit(X_train, y_train, verbose=True, eval_metric='huber')
	print(f'fit done: {round(time.time()-start, 2)} secs from start')

	submit_file_name = "lgbm_submit.csv"
	with open(submit_file_name, 'a') as f:
		f.write('row_id,meter_reading')
	for chunk in range(1,11):
		X_test, row_id = read_test(chunk)
		print(f'read {chunk}: {round(time.time()-start, 2)} secs from start')
		predicted = list(lgbm.predict(X_test))
		predicted = [round(math.exp(entry)-1, 4) for entry in predicted]
		print(f'scored {chunk}: {round(time.time()-start, 2)} secs from start')
		with open(submit_file_name, 'a') as f:
			for row_id, predicted in zip(row_id, predicted):
				f.write(f'\n{row_id},{predicted}')
