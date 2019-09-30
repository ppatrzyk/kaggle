import time
import pandas as pd
from functools import reduce

# from lightgbm import LGBMClassifier

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
