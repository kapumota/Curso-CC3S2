import pandas as pd
from pipeline import transform

def test_transform_squares_values():
    df_in = pd.DataFrame([
        {"name": "a", "value": 2},
        {"name": "b", "value": -3},
    ])
    df_out = transform(df_in)

    assert list(df_out["value_squared"]) == [4, 9]
    assert set(df_out.columns) == {"name", "value", "value_squared"}
