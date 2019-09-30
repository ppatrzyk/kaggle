import time
import pandas as pd
from sklearn.model_selection import GridSearchCV
from lightgbm import LGBMClassifier
from dataread import read_train

if __name__ == '__main__':
	start = time.time()
	X_train, y_train = read_train()
	print(f'read and transformed: {round(time.time()-start, 2)} secs from start')
	
	lgb = LGBMClassifier(
		learning_rate=0.1, class_weight=None, metric='auc',
		num_leaves=200, n_estimators=200, max_depth=-1,
		boosting_type='gbdt', colsample_bytree=1, subsample=1,
		subsample_for_bin=200000, objective='binary', min_split_gain=0.0, 
		min_child_weight=0.001, min_child_samples=20,
		subsample_freq=0, random_state=None, n_jobs=-1, 
		silent=False, importance_type='split'
	)
	param_grid = {
		'is_unbalance': [True, False],
		'boost_from_average': [True, False],
		'reg_alpha': [0, 0.1],
		'reg_lambda': [0, 0.1]
	}

	lgb_search = GridSearchCV(lgb, param_grid, cv=3, scoring='roc_auc', verbose=10, n_jobs=-1)
	lgb_search.fit(X_train, y_train)
	res = pd.DataFrame.from_dict(lgb_search.cv_results_)
	res.to_csv('lightgbm_gridsearch.csv')
	print(f'end: {round(time.time()-start, 2)} secs from start')
