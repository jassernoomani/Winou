"""Retrieval and verification metrics for same-individual matching.

Embeddings are L2-normalized, so the dot product is the cosine similarity.
"""
import numpy as np
import pandas as pd
from sklearn.metrics import roc_auc_score


def retrieval_topk(emb: np.ndarray, df: pd.DataFrame, ks=(1, 5), chunk: int = 1024) -> dict:
    """Top-k retrieval accuracy for every image that has a known identity.

    Each query is ranked against all other images in `df` (other individuals
    plus identity-less distractors). A hit means at least one image of the
    same individual appears in the top k.
    """
    identity = df["identity"].to_numpy()
    query_idx = np.flatnonzero(pd.notna(identity))
    hits = {k: 0 for k in ks}
    max_k = max(ks)

    for start in range(0, len(query_idx), chunk):
        q = query_idx[start:start + chunk]
        sims = emb[q] @ emb.T
        sims[np.arange(len(q)), q] = -np.inf  # never retrieve the query itself
        top = np.argpartition(-sims, max_k, axis=1)[:, :max_k]
        order = np.take_along_axis(sims, top, axis=1).argsort(axis=1)[:, ::-1]
        top = np.take_along_axis(top, order, axis=1)
        same = identity[top] == identity[q][:, None]
        for k in ks:
            hits[k] += int(same[:, :k].any(axis=1).sum())

    n = len(query_idx)
    return {"queries": n, **{f"top{k}": hits[k] / n for k in ks}}


def pair_similarities(emb: np.ndarray, df: pd.DataFrame, n_negatives: int = 200_000,
                      seed: int = 0) -> tuple[np.ndarray, np.ndarray]:
    """Cosine similarities for same-individual pairs and random different pairs.

    Positives: every pair of images of the same individual.
    Negatives: random pairs of images known to be different animals of the
    same species (two distractors are never paired, since they could be the
    same animal).
    """
    identity = df["identity"].to_numpy()
    species = df["species"].to_numpy()

    positives = []
    for _, idx in df.groupby("identity").indices.items():
        if len(idx) > 1:
            block = emb[idx] @ emb[idx].T
            positives.append(block[np.triu_indices(len(idx), k=1)])
    positives = np.concatenate(positives)

    rng = np.random.default_rng(seed)
    known = np.flatnonzero(pd.notna(identity))
    a = rng.choice(known, n_negatives * 2)
    b = rng.integers(0, len(df), n_negatives * 2)
    keep = (identity[a] != identity[b]) & (species[a] == species[b]) & (a != b)
    a, b = a[keep][:n_negatives], b[keep][:n_negatives]
    negatives = np.einsum("ij,ij->i", emb[a], emb[b])
    return positives, negatives


def threshold_table(positives: np.ndarray, negatives: np.ndarray,
                    target_fprs=(0.05, 0.01, 0.005, 0.001)) -> pd.DataFrame:
    """For each target false-positive rate, the threshold and resulting recall.

    `alerts_per_100` is the expected number of false match alerts when a new
    photo is compared against 100 candidate photos of other animals, which is
    roughly the size of a geo/time-filtered candidate pool in a city.
    """
    rows = []
    for fpr in target_fprs:
        threshold = float(np.quantile(negatives, 1 - fpr))
        rows.append({
            "target_fpr": fpr,
            "threshold": round(threshold, 4),
            "recall": round(float((positives >= threshold).mean()), 4),
            "alerts_per_100": round(100 * float((negatives >= threshold).mean()), 2),
        })
    return pd.DataFrame(rows)


def verification_auc(positives: np.ndarray, negatives: np.ndarray) -> float:
    labels = np.r_[np.ones(len(positives)), np.zeros(len(negatives))]
    return float(roc_auc_score(labels, np.r_[positives, negatives]))


def candidate_pool_accuracy(emb: np.ndarray, df: pd.DataFrame, pool_size: int,
                            n_queries: int = 2000, ks=(1, 3), seed: int = 0) -> dict:
    """Simulates the app: one new photo against `pool_size` nearby lost reports.

    The pool holds the true animal (all its other photos) plus `pool_size - 1`
    random other animals. Each report is scored by its best photo, as in the
    production pipeline. Returns how often the true animal ranks in the top k.
    """
    rng = np.random.default_rng(seed)
    groups = df.groupby("identity").indices
    pets = np.array(list(groups))
    identity = df["identity"].to_numpy()
    queries = rng.choice(np.flatnonzero(pd.notna(identity)), n_queries, replace=False)
    hits = {k: 0 for k in ks}
    for q in queries:
        others = rng.choice(pets[pets != identity[q]], pool_size - 1, replace=False)
        true_photos = [j for j in groups[identity[q]] if j != q]
        true_score = float((emb[true_photos] @ emb[q]).max())
        other_scores = np.array([(emb[groups[p]] @ emb[q]).max() for p in others])
        rank = int((other_scores > true_score).sum())
        for k in ks:
            hits[k] += rank < k
    return {f"pool{pool_size}_top{k}": hits[k] / n_queries for k in ks}


def breed_top1(emb: np.ndarray, df: pd.DataFrame, chunk: int = 1024) -> float:
    """How often the nearest neighbour of an image has the same breed.

    High values mean the model clusters strongly by breed, the main way it
    can confuse two different animals of the same breed.
    """
    sub = df[df["breed"].notna()]
    idx = sub.index.to_numpy()
    breed = df["breed"].to_numpy()
    correct = 0
    for start in range(0, len(idx), chunk):
        q = idx[start:start + chunk]
        sims = emb[q] @ emb[idx].T
        sims[np.arange(len(q)), np.arange(start, start + len(q))] = -np.inf
        correct += int((breed[idx[sims.argmax(axis=1)]] == breed[q]).sum())
    return correct / len(idx)
