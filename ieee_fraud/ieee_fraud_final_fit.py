import time
import os
import numpy as np
import pandas as pd
from dataread import read_train

import joblib

from lightgbm import LGBMClassifier

if __name__ == '__main__':
	for i in range(1, 16):
		start = time.time()
		X_train, y_train = read_train(undersample=True, undersample_number=i)
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
		joblib.dump(lgbm, f'lgbm_{i}.joblib')
		print(f'{i}: processed: {round(time.time()-start, 2)} secs from start')
