
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import LabelEncoder

dummy = [
	'cloud_coverage', 'primary_use', 'year_built',
	'floor_count', 'meter', 'building_id', 'site_id', 
	'weekday', 'hour', 'month', 'precip',
	'building_complete', 'weather_complete'
]

train_all = pd.read_csv("train_clean.csv", sep=",")
y_train = train_all['meter_reading'].values
train_all.drop('meter_reading', axis=1, inplace=True)
dummy_indices = [i for i, col in enumerate(list(train_all)) if col in dummy]

def read_train():
	train = train_all
	train = train.reindex(np.random.permutation(train.index))
	# X_train = train.values
	return X_train, y_train, dummy_indices

def read_test(chunk):
	file_name = f"test_clean{chunk}.csv"
	test = pd.read_csv(file_name, sep=",")
	row_id = test['row_id'].values
	test.drop(['row_id'], axis=1, inplace=True)
	X_test = test.values
	return X_test, row_id, dummy_indices
