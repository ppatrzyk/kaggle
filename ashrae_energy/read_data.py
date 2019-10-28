
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import OneHotEncoder

dummy = ['cloud_coverage', 'primary_use', 'meter', 'site_id', 'weekday', 'hour', 'month']

train_all = pd.read_csv("train_clean.csv", sep=",")
y_train = train_all['meter_reading'].values
train_all.drop('meter_reading', axis=1, inplace=True)
dummy_indices = [i for i, col in enumerate(list(train_all)) if col in dummy]
categories = [list(set(train_all[col].values)) for col in list(train_all) if col in dummy]

def read_train():
	train = train_all
	train = train.reindex(np.random.permutation(train.index))
	
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

def read_test():
	test = pd.read_csv("test_clean.csv", sep=",")
	row_id = test['row_id'].values
	test.drop(['row_id'], axis=1, inplace=True)
	ct = ColumnTransformer(
		transformers=[(
			'one_hot',
			OneHotEncoder(sparse=True, categories=categories, handle_unknown='ignore'),
			dummy_indices
		)],
		remainder='passthrough'
	)
	X_test = ct.fit_transform(test.values)
	return X_test, row_id
	