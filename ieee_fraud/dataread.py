
import re
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import OneHotEncoder

with open('categorical_cols.txt', 'r') as cat_raw:
	dummy = [re.sub('\n', '', l).strip() for l in cat_raw]
train_all = pd.read_csv("train_clean.csv", sep=",")
train_all.drop(['TransactionID'], axis=1, inplace=True)
train_cols = [el for el in list(train_all) if el != 'isFraud']
dummy_indices = [i for i, col in enumerate(train_cols) if col in dummy]
categories = [sorted(list(set(train_all[col].values))) for col in list(train_all) if col in dummy]


def read_train(undersample=False, undersample_number=0):
	if not undersample:
		train = train_all
	else:
		train = pd.read_csv(f"train_clean_undersample{undersample_number}.csv", sep=",")
		train.drop(['TransactionID'], axis=1, inplace=True)
	train = train.reindex(np.random.permutation(train.index))

	y_train = train['isFraud'].values
	train.drop('isFraud', axis=1, inplace=True)
	
	ct = ColumnTransformer(
		transformers=[(
			'one_hot',
			OneHotEncoder(sparse=True, categories=categories, handle_unknown='ignore'),
			dummy_indices
		)],
		remainder='passthrough'
	)
	X_train = ct.fit_transform(train.values)
	return X_train, y_train

def read_test(undersample=False, undersample_number=0):
	if not undersample:
		train = train_all
	else:
		train = pd.read_csv(f"train_clean_undersample{undersample_number}.csv", sep=",")
		train.drop(['TransactionID'], axis=1, inplace=True)
	test = pd.read_csv("test_clean.csv", sep=",")

	trans_id = test['TransactionID'].values
	test.drop(['TransactionID'], axis=1, inplace=True)

	ct = ColumnTransformer(
		transformers=[(
			'one_hot',
			OneHotEncoder(sparse=True, categories=categories, handle_unknown='ignore'),
			dummy_indices
		)],
		remainder='passthrough'
	)
	X_test = ct.fit_transform(test.values)
	return X_test, trans_id
