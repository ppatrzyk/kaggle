import time
import pandas as pd
from sklearn.model_selection import GridSearchCV
from xgboost import XGBClassifier
from dataread import read_train

if __name__ == '__main__':
	start = time.time()
	X_train, y_train = read_train()
	print(f'read and transformed: {round(time.time()-start, 2)} secs from start')

	xgb = XGBClassifier(
		booster='gbtree', learning_rate=0.1,
		verbosity=1, objective='binary:logistic',
		n_jobs=1, gamma=0, n_estimators=100, 
		min_child_weight=1, max_delta_step=0,
		subsample=1, colsample_bytree=1,
		colsample_bylevel=1, colsample_bynode=1,
		scale_pos_weight=1,
		base_score=0.5, random_state=0
	)
	param_grid = {
		'reg_alpha': [0, 0.15, 0.3], 
		'reg_lambda': [0, 0.15, 0.3],
		'max_depth': [10, 50]
	}
	xgb_search = GridSearchCV(xgb, param_grid, cv=3, scoring='roc_auc', verbose=10, n_jobs=4)
	xgb_search.fit(X_train, y_train)
	res = pd.DataFrame.from_dict(xgb_search.cv_results_)
	res.to_csv('xgboost_gridsearch.csv')
	print(f'end: {round(time.time()-start, 2)} secs from start')
