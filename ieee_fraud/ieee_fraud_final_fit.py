import time
import os
import numpy as np
import pandas as pd
from dataread import read_train

import joblib

from lightgbm import LGBMClassifier

if __name__ == '__main__':
	start = time.time()
	X_train, y_train = read_train()
	print(f'read and transformed: {round(time.time()-start, 2)} secs from start')

	for estimators in [100, 150, 200, 300, 400]:
		lgbm = LGBMClassifier(
			n_estimators=estimators,
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
		joblib.dump(lgbm, f'lgbm_{estimators}.joblib')
