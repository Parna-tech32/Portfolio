"""run_results.py - runs the comparison and sensitivity sweeps, writes charts + CSV to ./out"""
from dataclasses import replace
from pathlib import Path
import numpy as np, pandas as pd
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from hess_model import Params, compare, simulate, load_cycle

OUT = Path(__file__).resolve().parent / "out"; OUT.mkdir(exist_ok=True)
NAVY, RED, SLATE, GREY = "#1E3A8A", "#DC2626", "#64748B", "#CBD5E1"
plt.rcParams.update({"font.family": "DejaVu Sans", "axes.spines.top": False, "axes.spines.right": False,
                     "axes.grid": True, "axes.axisbelow": True, "grid.color": "#E2E8F0", "axes.edgecolor": "#94A3B8", "font.size": 11})
COL = {"A": SLATE, "B": "#60A5FA", "C": NAVY}
NAME = {"A": "A: Battery only", "B": "B: Filter split", "C": "C: SOC-aware (ours)"}

p = replace(Params(), uc_f=75.0, p_conv_max=625.0)   # deck base case: 75 F UC, 500 W ISG, converter rated 1.25x ISG
cyc = load_cycle(p=p)
res, _ = compare(p, cyc)
df = pd.DataFrame({c: m for c, (m, _) in res.items()}).round(3)
df.to_csv(OUT / "results_base_case.csv"); print(df.to_string())

# ---------- Fig 1: time series ----------
t = cyc["t"]
fig, ax = plt.subplots(3, 1, figsize=(11, 8), sharex=True)
ax[0].plot(t, cyc["v"] * 3.6, color=NAVY); ax[0].set_ylabel("Speed (km/h)"); ax[0].set_title("WLTC 2W drive cycle")
ax[1].plot(t, np.abs(res["A"][1]["i_bat"]), color=SLATE, lw=1.4, label="A: battery only")
ax[1].plot(t, np.abs(res["C"][1]["i_bat"]), color=NAVY, lw=1.6, label="C: SOC-aware (ours)")
ax[1].set_ylabel("Battery current |I| (A)"); ax[1].set_ylim(0, 31); ax[1].legend(loc="upper left", frameon=False, ncol=2)
ax[1].set_title("Battery current: the UC takes the peaks (the steady ~5 A at idle is the battery pre-charging the UC)", fontsize=11)
ax[2].plot(t, res["C"][1]["v_uc"], color=NAVY, label="UC voltage (C)")
ax[2].plot(t, res["B"][1]["v_uc"], color="#60A5FA", lw=1, label="UC voltage (B)")
ax[2].axhline(p.uc_vmax, color=RED, ls="--", lw=1); ax[2].axhline(p.uc_vmin, color=RED, ls="--", lw=1)
ax[2].set_ylabel("UC voltage (V)"); ax[2].set_xlabel("Time (s)"); ax[2].legend(loc="lower left", frameon=False, ncol=2)
ax[2].set_title("UC stays inside its 8-16 V window")
fig.tight_layout(); fig.savefig(OUT / "fig1_timeseries.png", dpi=150); plt.close(fig)

# ---------- Fig 2: key metrics ----------
panels = [("peak_c_rate", "Peak battery C-rate", "{:.1f}C"), ("secs_above_stress_c", "Seconds above 2C", "{:.0f} s"),
          ("regen_capture_pct", "Regen energy captured (%)", "{:.0f}%"), ("reuse_pct", "Wheel energy supplied by\nrecovered energy (%)", "{:.1f}%")]
fig, ax = plt.subplots(1, 4, figsize=(13, 3.8))
for a_, (k, ttl, fmt) in zip(ax, panels):
    vals = [df.loc[k, c] for c in "ABC"]
    b = a_.bar(["A", "B", "C"], vals, color=[COL[c] for c in "ABC"], width=0.6)
    for r, v_ in zip(b, vals): a_.text(r.get_x() + r.get_width() / 2, v_, fmt.format(v_), ha="center", va="bottom", fontsize=10)
    a_.set_title(ttl, fontsize=11); a_.set_ylim(0, max(vals) * 1.22); a_.grid(axis="x", visible=False)
fig.suptitle("A: battery only   B: filter split   C: SOC-aware (ours)", y=1.02, fontsize=10, color="#475569")
fig.tight_layout(); fig.savefig(OUT / "fig2_metrics.png", dpi=150, bbox_inches="tight"); plt.close(fig)

# ---------- Sweep 1: UC size ----------
rows = []
for f in [0, 10, 25, 50, 75, 100, 126, 160, 200, 300]:
    q = replace(p, uc_f=float(f)); m, _ = simulate("C" if f > 0 else "A", q, cyc)
    rows.append(dict(uc_f=f, **m))
sz = pd.DataFrame(rows); sz.to_csv(OUT / "sweep_uc_size.csv", index=False)
fig, ax = plt.subplots(1, 3, figsize=(13, 3.8))
for a_, (k, ttl) in zip(ax, [("secs_above_stress_c", "Seconds above 2C"), ("regen_capture_pct", "Regen captured (%)"), ("reuse_pct", "Wheel energy from recovered energy (%)")]):
    a_.plot(sz.uc_f, sz[k], "-o", color=NAVY); a_.set_title(ttl, fontsize=11); a_.set_xlabel("UC size (F)")
    a_.axvline(126, color=RED, ls="--", lw=1)
ax[0].text(130, ax[0].get_ylim()[1] * 0.9, "126 F\n(upper bound)", color=RED, fontsize=9)
fig.tight_layout(); fig.savefig(OUT / "fig3_uc_size.png", dpi=150, bbox_inches="tight"); plt.close(fig)

# ---------- Sweep 2: where does the UC help? (ISG power x battery charge acceptance) ----------
isg = [300, 500, 800, 1200]; chg = [1, 2, 3, 4]
gain = np.zeros((len(chg), len(isg))); capA = np.zeros_like(gain); capC = np.zeros_like(gain)
for i, cc in enumerate(chg):
    for j, pw in enumerate(isg):
        q = replace(p, p_isg_max=float(pw), p_conv_max=1.25 * pw, i_chg_c=float(cc), uc_f=0.2 * pw)   # UC sized by the 0.2 F/W rule
        mA, _ = simulate("A", q, cyc); mC, _ = simulate("C", q, cyc)
        gain[i, j] = mC["reuse_pct"] - mA["reuse_pct"]; capA[i, j] = mA["regen_capture_pct"]; capC[i, j] = mC["regen_capture_pct"]
pd.DataFrame(gain, index=[f"{c}C" for c in chg], columns=[f"{w} W" for w in isg]).round(2).to_csv(OUT / "sweep_isg_vs_chargeC_reuse_gain.csv")
fig, ax = plt.subplots(figsize=(6.4, 4.2))
im = ax.imshow(gain, cmap="Blues", aspect="auto", origin="lower")
ax.set_xticks(range(len(isg)), [f"{w} W" for w in isg]); ax.set_yticks(range(len(chg)), [f"{c}C" for c in chg])
ax.set_xlabel("ISG power limit"); ax.set_ylabel("Battery charge acceptance"); ax.grid(False)
for i in range(len(chg)):
    for j in range(len(isg)): ax.text(j, i, f"+{gain[i, j]:.1f}", ha="center", va="center", color="white" if gain[i, j] > gain.max() * 0.55 else "#0F172A")
ax.set_title("Extra wheel energy supplied by recovery,\nSOC-aware UC vs. battery only (percentage points)", fontsize=10.5)
fig.tight_layout(); fig.savefig(OUT / "fig4_where_uc_helps.png", dpi=150); plt.close(fig)

# ---------- Sweep 3: filter time constant (B vs C) ----------
rows = []
for tf in [0.5, 1, 2, 5, 10]:
    q = replace(p, tf=float(tf))
    for c in "BC":
        m, _ = simulate(c, q, cyc); rows.append(dict(tf=tf, case=c, **m))
pd.DataFrame(rows).to_csv(OUT / "sweep_filter_tf.csv", index=False)
print("\nUC size sweep\n", sz[["uc_f", "peak_c_rate", "secs_above_stress_c", "regen_capture_pct", "reuse_pct"]].round(2).to_string(index=False))
print("\nreuse gain C-A (pp), rows=charge C, cols=ISG W\n", pd.DataFrame(gain, index=chg, columns=isg).round(2))
print("\nregen capture A\n", pd.DataFrame(capA, index=chg, columns=isg).round(0))
print("\nregen capture C\n", pd.DataFrame(capC, index=chg, columns=isg).round(0))
print("\nTf sweep\n", pd.DataFrame(rows)[["tf", "case", "peak_c_rate", "secs_above_stress_c", "regen_capture_pct", "reuse_pct"]].round(2).to_string(index=False))

# ---------- Sweep 4: UC size needed vs ISG power ----------
sizes = [10, 15, 20, 30, 40, 50, 60, 75, 100, 126, 160, 200, 300, 400]
need = []
for pw in [300, 500, 800, 1200, 1500]:
    ok = None
    for f in sizes:
        m, _ = simulate("C", replace(p, p_isg_max=float(pw), p_conv_max=1.25 * pw, uc_f=float(f)), cyc)
        if m["regen_capture_pct"] >= 95 and m["secs_above_stress_c"] == 0: ok = f; break
    need.append((pw, ok))
nd = pd.DataFrame(need, columns=["isg_w", "min_uc_f"]); nd.to_csv(OUT / "sweep_min_uc_vs_isg.csv", index=False); print("\nMin UC size for >=95% regen and 0 s above 2C\n", nd.to_string(index=False))
fig, ax = plt.subplots(figsize=(6.4, 4.2))
ax.plot(nd.isg_w, nd.min_uc_f, "-o", color=NAVY); ax.axhline(126, color=RED, ls="--", lw=1)
ax.text(nd.isg_w.min(), 130, "126 F: wheel-level upper bound", color=RED, fontsize=9)
ax.set_xlabel("ISG power limit (W)"); ax.set_ylabel("Smallest UC that works (F)"); ax.set_title("UC size needed grows with ISG power", fontsize=11)
fig.tight_layout(); fig.savefig(OUT / "fig5_min_uc_vs_isg.png", dpi=150); plt.close(fig)

# ---------- Ablation: what part of C does the work? ----------
abl = {}
for name, q in [("B filter only", None), ("C w/o SOC regulator", replace(p, p_corr_max=0.0)), ("C full", p)]:
    for f in (30, 50, 126):
        qq = replace(q or p, uc_f=float(f)); m, _ = simulate("B" if q is None else "C", qq, cyc)
        abl[(name, f)] = {k: m[k] for k in ("peak_c_rate", "secs_above_stress_c", "regen_capture_pct", "reuse_pct")}
print("\nAblation (UC size F)\n", pd.DataFrame(abl).T.round(2).to_string())
pd.DataFrame(abl).T.round(3).to_csv(OUT / "ablation.csv")
