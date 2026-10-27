import numpy as np
import pandas as pd

from src.metrics import pair_similarities, retrieval_topk, threshold_table


def _toy():
    # Two individuals with 2 images each, plus one distractor.
    emb = np.array([
        [1.0, 0.0], [0.99, 0.14],   # dog A
        [0.0, 1.0], [0.14, 0.99],   # dog B
        [0.7, 0.7],                 # distractor
    ])
    emb /= np.linalg.norm(emb, axis=1, keepdims=True)
    df = pd.DataFrame({
        "species": ["dog"] * 5,
        "breed": [None] * 5,
        "identity": ["A", "A", "B", "B", None],
    })
    return emb, df


def test_retrieval_finds_same_individual():
    emb, df = _toy()
    result = retrieval_topk(emb, df, ks=(1, 2))
    assert result["queries"] == 4
    assert result["top1"] == 1.0


def test_query_never_matches_itself():
    emb, df = _toy()
    df.loc[1, "identity"] = "C"  # A now has a single image, so its query must miss
    result = retrieval_topk(emb, df, ks=(1,))
    assert result["top1"] == 0.5


def test_pairs_and_thresholds():
    emb, df = _toy()
    pos, neg = pair_similarities(emb, df, n_negatives=50)
    assert len(pos) == 2
    assert pos.min() > neg.max()
    table = threshold_table(pos, neg, target_fprs=(0.01,))
    assert table.loc[0, "recall"] == 1.0
