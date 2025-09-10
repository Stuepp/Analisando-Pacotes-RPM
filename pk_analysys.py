import pandas as pd
#import plotly.express as px

df = pd.read_csv('rpm_all_info.csv')

df['Signature_Alg_Size'] = df.loc[:,'Signature'].str.split(',')[0][0]

print( df.loc[:,'Signature_Alg_Size'].unique())

condition = df.loc[:, 'Signature'].str.contains('none')

print(df.loc[condition, 'Signature'].count())
print(df.loc[~condition, 'Signature'].count())

# Tá... isso diz que os .sh estão fazendo caquinha....