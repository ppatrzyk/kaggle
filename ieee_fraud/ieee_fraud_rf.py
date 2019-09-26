import time
import statistics
import pandas as pd

from sklearn.ensemble import RandomForestClassifier
from dataread import read_train, read_test

if __name__ == '__main__':

	start = time.time()

	forests = []
	for i in range(1, 16):
		X_train, y_train = read_train(undersample=True, undersample_number=i)
		rf = RandomForestClassifier(
			n_estimators=50, min_samples_leaf=2,
			max_depth=None, max_features='sqrt',
			class_weight='balanced', criterion='gini',
			min_samples_split=2, min_weight_fraction_leaf=0.0, 
			max_leaf_nodes=None, min_impurity_decrease=0.0, 
			min_impurity_split=None, bootstrap=False, 
			oob_score=False, random_state=None, verbose=0, warm_start=False
		)
		rf.fit(X_train, y_train)
		forests.append(rf)
		print(f'{i}: fit done: {round(time.time()-start, 2)} secs from start')

	rf_probs_all = []
	for i in range(1, 16):
		rf = forests[i-1]
		X_test, trans_id = read_test(undersample=True, undersample_number=i)
		rf_probs_all.append(rf.predict_proba(X_test)[:,1])
		print(f'{i} scoring: {round(time.time()-start, 2)} secs from start')

	rf_probs = []
	for index in range(len(rf_probs_all[0])):
		entry = [el[index] for el in rf_probs_all]
		rf_probs.append(statistics.mean(entry))

	rf_probs = ["{:.5f}".format(prob) for prob in rf_probs]
	rf_submit = pd.DataFrame({
		'TransactionID': trans_id,
		'isFraud': rf_probs
	})

	rf_submit.to_csv(f'rf_submit.csv', index=False, header=True)