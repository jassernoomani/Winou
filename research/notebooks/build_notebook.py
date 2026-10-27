"""Generates phase0_matching.ipynb so the notebook source stays reviewable in git.

    python notebooks/build_notebook.py
"""
from pathlib import Path

import nbformat as nbf

md, code = nbf.v4.new_markdown_cell, nbf.v4.new_code_cell

cells = [
    md("# Phase 0: can embeddings tell individual animals apart?\n\n"
       "We compare **CLIP ViT-B/16** and **DINOv2 ViT-B/14**, each on the full image and on a "
       "YOLO crop. Embeddings are produced by `python -m src.embed_all` and cached in "
       "`outputs/embeddings/`.\n\n"
       "Every query is ranked against the other images of its dataset **plus all Oxford-IIIT "
       "images of the same species** as distractors (thousands of animals that look similar but are "
       "different). That mimics the app, where a sighting is compared to every same-species "
       "report nearby."),
    code("import sys; sys.path.insert(0, '..')\n"
         "from pathlib import Path\n"
         "import numpy as np, pandas as pd, matplotlib.pyplot as plt\n"
         "from src import metrics\n\n"
         "EMB = Path('../outputs/embeddings'); OUT = Path('../outputs')\n"
         "MODELS, CROPS = ['clip-b16', 'dinov2-b14'], ['full', 'crop']\n"
         "IDENTITY_SETS = [n for n in ['dogfacenet', 'petfinder', 'petface_cat', 'petface_dog', 'own']\n"
         "                 if (EMB / f'{n}_index.csv').exists()]\n\n"
         "def load(name, model, crop):\n"
         "    return pd.read_csv(EMB / f'{name}_index.csv'), np.load(EMB / f'{name}_{model}_{crop}.npy')\n\n"
         "IDENTITY_SETS"),
    md("## 1. Detection rate\nShare of images where YOLO found a cat or dog. In the app, a photo "
       "without a detection is rejected as unusable."),
    code("rows = []\n"
         "for name in ['oxford', *IDENTITY_SETS]:\n"
         "    idx = pd.read_csv(EMB / f'{name}_index.csv')\n"
         "    rows.append({'dataset': name, 'images': len(idx),\n"
         "                 'identities': idx['identity'].nunique(),\n"
         "                 'detected': round(idx['det_conf'].notna().mean(), 3),\n"
         "                 'species_agrees': round((idx['det_species'] == idx['species']).mean(), 3)})\n"
         "detection = pd.DataFrame(rows); detection"),
    md("## 2. Same-individual retrieval and verification\n"
       "- **top1 / top5**: a photo of the same animal is ranked first / in the first five.\n"
       "- **AUC**: how well the similarity score alone separates same-animal pairs from "
       "different-animal pairs (1.0 = perfect)."),
    code("results, pairs = [], {}\n"
         "for name in IDENTITY_SETS:\n"
         "    for model in MODELS:\n"
         "        for crop in CROPS:\n"
         "            df, emb = load(name, model, crop)\n"
         "            ox_df, ox_emb = load('oxford', model, crop)\n"
         "            keep = ox_df['species'].isin(df['species'].unique()).to_numpy()\n"
         "            all_df = pd.concat([df, ox_df[keep]], ignore_index=True)\n"
         "            all_emb = np.vstack([emb, ox_emb[keep]])\n"
         "            top = metrics.retrieval_topk(all_emb, all_df)\n"
         "            pos, neg = metrics.pair_similarities(all_emb, all_df)\n"
         "            pairs[name, model, crop] = (pos, neg)\n"
         "            results.append({'dataset': name, 'model': model, 'crop': crop,\n"
         "                            'distractors': int(keep.sum()), **top,\n"
         "                            'auc': metrics.verification_auc(pos, neg)})\n"
         "results = pd.DataFrame(results).round(3)\n"
         "results.to_csv(OUT / 'retrieval_results.csv', index=False)\n"
         "results"),
    md("## 3. Breed clustering (Oxford-IIIT)\nHow often the nearest neighbour is the same breed. "
       "High values mean the model groups animals by breed, which is how it can confuse two "
       "different animals of the same breed."),
    code("breed = pd.DataFrame([{'model': m, 'crop': c,\n"
         "                       'breed_top1': metrics.breed_top1(load('oxford', m, c)[1], load('oxford', m, c)[0])}\n"
         "                      for m in MODELS for c in CROPS]).round(3)\n"
         "breed"),
    md("## 4. Similarity distributions\nSame-animal pairs versus random different-animal pairs "
       "(same species)."),
    code("for name in IDENTITY_SETS:\n"
         "    fig, axes = plt.subplots(1, 4, figsize=(18, 3.5), sharey=True)\n"
         "    for ax, (model, crop) in zip(axes, [(m, c) for m in MODELS for c in CROPS]):\n"
         "        pos, neg = pairs[name, model, crop]\n"
         "        ax.hist(neg, bins=80, density=True, alpha=.6, label='different animal')\n"
         "        ax.hist(pos, bins=80, density=True, alpha=.6, label='same animal')\n"
         "        ax.set_title(f'{model} / {crop}'); ax.set_xlabel('cosine similarity')\n"
         "    axes[0].legend(); fig.suptitle(name); fig.tight_layout()\n"
         "    fig.savefig(OUT / f'similarity_{name}.png', dpi=110)"),
    md("## 5. Threshold suggestions\nFor each target false-positive rate: the cosine threshold, "
       "the share of true matches kept (recall), and the expected number of false alerts when one "
       "new photo is compared against 100 candidate photos (roughly a geo/time-filtered pool)."),
    code("best = results.sort_values(['dataset', 'top1', 'auc'], ascending=[True, False, False]).groupby('dataset').head(1)\n"
         "for r in best.itertuples():\n"
         "    print(f'\\n{r.dataset}: {r.model} / {r.crop}')\n"
         "    display(metrics.threshold_table(*pairs[r.dataset, r.model, r.crop]))"),
    md("## 6. Thresholds for every setting (to compare models on equal footing)"),
    code("tables = []\n"
         "for (name, model, crop), (pos, neg) in pairs.items():\n"
         "    t = metrics.threshold_table(pos, neg)\n"
         "    t.insert(0, 'setting', f'{name} | {model} | {crop}')\n"
         "    tables.append(t)\n"
         "thresholds = pd.concat(tables, ignore_index=True)\n"
         "thresholds.to_csv(OUT / 'thresholds.csv', index=False)\n"
         "thresholds[thresholds['target_fpr'] == 0.01]"),
    md("## 7. PetFinder by species (DINOv2)\nPetFinder holds real phone photos of shelter animals, "
       "the closest match to app conditions. Cats and dogs are evaluated separately because they "
       "need different thresholds."),
    code("species_rows = []\n"
         "if 'petfinder' in IDENTITY_SETS:\n"
         "    for sp in ['cat', 'dog']:\n"
         "        for crop in CROPS:\n"
         "            df, emb = load('petfinder', 'dinov2-b14', crop)\n"
         "            ox_df, ox_emb = load('oxford', 'dinov2-b14', crop)\n"
         "            a, b = (df['species'] == sp).to_numpy(), (ox_df['species'] == sp).to_numpy()\n"
         "            all_df = pd.concat([df[a], ox_df[b]], ignore_index=True)\n"
         "            all_emb = np.vstack([emb[a], ox_emb[b]])\n"
         "            pos, neg = metrics.pair_similarities(all_emb, all_df)\n"
         "            t = metrics.threshold_table(pos, neg, target_fprs=(0.01,)).iloc[0]\n"
         "            species_rows.append({'species': sp, 'crop': crop, **metrics.retrieval_topk(all_emb, all_df),\n"
         "                                 'auc': metrics.verification_auc(pos, neg),\n"
         "                                 'thr_at_1pct_fpr': t['threshold'], 'recall_at_thr': t['recall']})\n"
         "by_species = pd.DataFrame(species_rows).round(3)\n"
         "by_species.to_csv(OUT / 'petfinder_by_species.csv', index=False)\n"
         "by_species"),
    md("## 8. Realistic candidate pools\nIn the app a sighting is only compared with lost reports "
       "inside the geo radius and time window, i.e. tens to a few hundred animals, not thousands. "
       "Each report is scored by its best photo. How often does the true animal rank first / in "
       "the top 3?"),
    code("pool_rows = []\n"
         "if 'petfinder' in IDENTITY_SETS:\n"
         "    for sp in ['cat', 'dog']:\n"
         "        for crop in CROPS:\n"
         "            df, emb = load('petfinder', 'dinov2-b14', crop)\n"
         "            a = (df['species'] == sp).to_numpy()\n"
         "            row = {'species': sp, 'crop': crop}\n"
         "            for n in (50, 200):\n"
         "                row.update(metrics.candidate_pool_accuracy(emb[a], df[a].reset_index(drop=True), n))\n"
         "            pool_rows.append(row)\n"
         "pools = pd.DataFrame(pool_rows).round(3)\n"
         "pools.to_csv(OUT / 'candidate_pools.csv', index=False)\n"
         "pools"),
]

nb = nbf.v4.new_notebook(cells=cells, metadata={"kernelspec": {"name": "python3", "display_name": "Python 3"}})
nbf.write(nb, Path(__file__).with_name("phase0_matching.ipynb"))
print("wrote phase0_matching.ipynb")
