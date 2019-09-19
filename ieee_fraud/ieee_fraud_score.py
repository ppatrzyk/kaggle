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

	lgbm = joblib.load('lgbm.joblib')
	lgbm_probs = [round(prob, 5) for prob in lgbm.predict_proba(X_test)[:,1]]
	lgbm_submit = pd.DataFrame({
		'TransactionID': trans_id,
		'isFraud': lgbm_probs
	})
	lgbm_submit.to_csv('lgbm_submit.csv', index=False, header=True)
	print(f'lgbm processed: {round(time.time()-start, 2)} secs from start')
