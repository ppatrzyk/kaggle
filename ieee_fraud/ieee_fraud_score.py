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

	lgbm_200 = joblib.load('lgbm_200.joblib')
	lgbm_200_probs = ["{:.5f}".format(prob) for prob in lgbm_200.predict_proba(X_test)[:,1]]
	lgbm_200_submit = pd.DataFrame({
		'TransactionID': trans_id,
		'isFraud': lgbm_200_probs
	})
	lgbm_200_submit.to_csv('lgbm_200_submit.csv', index=False, header=True)
	print(f'lgbm_200 processed: {round(time.time()-start, 2)} secs from start')

	lgbm_500 = joblib.load('lgbm_500.joblib')
	lgbm_500_probs = ["{:.5f}".format(prob) for prob in lgbm_500.predict_proba(X_test)[:,1]]
	lgbm_500_submit = pd.DataFrame({
		'TransactionID': trans_id,
		'isFraud': lgbm_500_probs
	})
	lgbm_500_submit.to_csv('lgbm_500_submit.csv', index=False, header=True)
	print(f'lgbm_500 processed: {round(time.time()-start, 2)} secs from start')
	