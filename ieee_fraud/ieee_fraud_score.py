import time
import os
import numpy as np
import pandas as pd
from dataread import read_test

import joblib

if __name__ == '__main__':
	start = time.time()
	X_test, trans_id = read_test()

	print(f'transformed and splitted: {round(time.time()-start, 2)} secs from start')

	for estimators in [100, 150, 200, 300, 400]:
		lgbm = joblib.load(f'lgbm_{estimators}.joblib')
		lgbm_probs = ["{:.5f}".format(prob) for prob in lgbm.predict_proba(X_test)[:,1]]
		lgbm_submit = pd.DataFrame({
			'TransactionID': trans_id,
			'isFraud': lgbm_probs
		})
		lgbm_submit.to_csv(f'lgbm_{estimators}_submit.csv', index=False, header=True)
		print(f'lgbm_{estimators} processed: {round(time.time()-start, 2)} secs from start')
