import time
import pandas as pd
from dataread import read_train, read_test

from lightgbm import LGBMClassifier

if __name__ == '__main__':
	start = time.time()
	X_train, y_train = read_train()
	lgbm = LGBMClassifier(
		n_estimators=100,
		num_leaves=200,
		boost_from_average=True,
		is_unbalance=False,
		learning_rate=0.1,
		reg_alpha=0,
		reg_lambda=0.1,
		max_depth=-1,
		boosting_type='gbdt', colsample_bytree=1, subsample=1,
		subsample_for_bin=200000, objective='binary', 
		class_weight=None, min_split_gain=0.0, 
		min_child_weight=0.001, min_child_samples=20,
		subsample_freq=0, random_state=None, n_jobs=-1, 
		silent=False, importance_type='split'
	)
	lgbm.fit(X_train, y_train)
	print(f'fit done: {round(time.time()-start, 2)} secs from start')

	X_test, trans_id = read_test()
	lgbm_probs = ["{:.5f}".format(prob) for prob in lgbm.predict_proba(X_test)[:,1]]
	print(f'scoring: {round(time.time()-start, 2)} secs from start')

	lgbm_submit = pd.DataFrame({
		'TransactionID': trans_id,
		'isFraud': lgbm_probs
	})
	lgbm_submit.to_csv(f'lgbm_all_submit.csv', index=False, header=True)
