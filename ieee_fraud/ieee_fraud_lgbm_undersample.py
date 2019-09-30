import time
import random
import pandas as pd
from dataread import read_train, read_test

from lightgbm import LGBMClassifier

if __name__ == '__main__':
	start = time.time()

	lgbm_models = []
	for i in range(1, 31):
		X_train, y_train = read_train(undersample=True, undersample_number=i)
		leaves = int(random.uniform(200, 400))
		regalpha = random.uniform(0, 0.4)
		reglambda = random.uniform(0, 0.4)
		child_weight = random.uniform(0.0005, 0.1)
		min_data_in_leaf = int(random.uniform(10, 80))
		boosting_type = random.sample(['gbdt', 'dart'], 1)[0]
		lgbm = LGBMClassifier(
			n_estimators=100,
			num_leaves=leaves,
			boost_from_average=True,
			is_unbalance=False,
			learning_rate=0.1,
			reg_alpha=regalpha,
			reg_lambda=reglambda,
			max_depth=-1,
			min_data_in_leaf=min_data_in_leaf,
			boosting_type=boosting_type, 
			colsample_bytree=1, subsample=1,
			subsample_for_bin=200000, objective='binary', 
			class_weight=None, min_split_gain=0.0, 
			min_child_weight=child_weight,
			subsample_freq=0, random_state=None, n_jobs=-1, 
			silent=False, importance_type='split'
		)
		lgbm.fit(X_train, y_train)
		lgbm_models.append(lgbm)
		print(f'{i}: fit done: {round(time.time()-start, 2)} secs from start')

	for i in range(1, 31):
		lgbm = lgbm_models[i-1]
		X_test, trans_id = read_test(undersample=True, undersample_number=i)
		lgbm_probs = lgbm.predict_proba(X_test)[:,1]
		lgbm_probs = ["{:.5f}".format(prob) for prob in lgbm_probs]
		lgbm_submit = pd.DataFrame({
			'TransactionID': trans_id,
			'isFraud': lgbm_probs
		})
		lgbm_submit.to_csv(f'lgbm_under{i}.csv', index=False, header=True)
		print(f'{i} scoring: {round(time.time()-start, 2)} secs from start')
