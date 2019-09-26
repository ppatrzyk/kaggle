import time
import os
# import numpy as np
import statistics
import pandas as pd
from dataread import read_test

import joblib

if __name__ == '__main__':
	
	lgbm_probs_all = []
	for i in range(1, 16):
		start = time.time()
		X_test, trans_id = read_test(undersample=True, undersample_number=i)
		lgbm = joblib.load(f'lgbm_{i}.joblib')
		lgbm_probs_all.append(lgbm.predict_proba(X_test)[:,1])
		print(f'lgbm_{i} processed: {round(time.time()-start, 2)} secs from start')

	lgbm_probs = []
	for index in range(len(lgbm_probs_all[0])):
		entry = [el[index] for el in lgbm_probs_all]
		lgbm_probs.append(statistics.mean(entry))

	lgbm_probs = ["{:.5f}".format(prob) for prob in lgbm_probs]
	lgbm_submit = pd.DataFrame({
		'TransactionID': trans_id,
		'isFraud': lgbm_probs
	})

	lgbm_submit.to_csv(f'lgbm_{i}_submit.csv', index=False, header=True)
