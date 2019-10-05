import time
import pandas as pd
from functools import reduce

from sklearn.linear_model import SGDClassifier
from dataread import read_train, read_test

DATASETS = 30

if __name__ == '__main__':
	start = time.time()

	preds_all = []
	for i in range(1, DATASETS+1):
		preds = pd.read_csv(f'lgbm_under{i}.csv')
		preds_all.append(preds)
		print(f'{i}: data read: {round(time.time()-start, 2)} secs from start')

	avg = reduce(lambda left, right: pd.merge(left, right, on='TransactionID'), preds_all)
	avg['avg'] = avg.drop(columns=['TransactionID']).mean(axis=1)
	avg = avg[['TransactionID','avg']]
	avg.rename(columns={'avg': 'isFraud'}, inplace=True)
	avg['isFraud'] = ["{:.5f}".format(el) for el in avg.isFraud.values]
	avg.to_csv('lgbm_under_mean_submit.csv', index=False, header=True)
	print(f'mean done: {round(time.time()-start, 2)} secs from start')

	for i, preds in enumerate(preds_all, start=1):
		preds[f'rank{i}'] = preds['isFraud'].rank()
		preds.drop(columns=['isFraud'], inplace=True)
	ranks = reduce(lambda left, right: pd.merge(left, right, on='TransactionID'), preds_all)
	ranks['avg_rank'] = ranks.drop(columns=['TransactionID']).mean(axis=1)
	avg_rank = ranks[['TransactionID','avg_rank']]
	avg_rank['avg_rank'] = avg_rank['avg_rank'] / avg_rank['avg_rank'].max()
	avg_rank.rename(columns={'avg_rank': 'isFraud'}, inplace=True)
	avg_rank['isFraud'] = ["{:.5f}".format(el) for el in avg_rank.isFraud.values]
	avg_rank.to_csv('lgbm_under_avgrank_submit.csv', index=False, header=True)
	print(f'meanrank done: {round(time.time()-start, 2)} secs from start')

	train_all = pd.read_csv("train_clean.csv", sep=",")
	train_all = train_all[['TransactionID', 'isFraud']]
	train = pd.read_csv('lgbm_under_blend_data.csv')
	train = pd.merge(train, train_all, on='TransactionID')
	train.drop(['TransactionID'], axis=1, inplace=True)
	for i, df in enumerate(preds_all, start=1):
		df.rename(columns={'isFraud': f'm{i}'}, inplace=True)
	test = reduce(lambda left, right: pd.merge(left, right, on='TransactionID'), preds_all)
	trans_id = test['TransactionID'].values
	test.drop(['TransactionID'], axis=1, inplace=True)
	y_train = train['isFraud'].values
	train.drop('isFraud', axis=1, inplace=True)
	X_train = train.values
	X_test = test.values
	sgd = SGDClassifier(
		loss='log', penalty='l2', alpha=0.0001, 
		l1_ratio=0.15, fit_intercept=True,
		max_iter=1000, tol=0.001, shuffle=True, verbose=100, 
		epsilon=0.1, n_jobs=None, random_state=None, learning_rate='optimal', eta0=0.0, power_t=0.5, 
		early_stopping=True, validation_fraction=0.1, n_iter_no_change=10, 
		class_weight=None, warm_start=False, average=False
	)
	sgd.fit(X_train, y_train)
	sgd_probs = ["{:.5f}".format(prob) for prob in sgd.predict_proba(X_test)[:,1]]
	sgd_submit = pd.DataFrame({
		'TransactionID': trans_id,
		'isFraud': sgd_probs
	})
	sgd_submit.to_csv(f'lgbm_blend_submit.csv', index=False, header=True)
	print(f'blend done: {round(time.time()-start, 2)} secs from start')
