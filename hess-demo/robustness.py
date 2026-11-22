"""robustness.py - (1) riding-style variants of WLTC 2W, (2) Monte Carlo over the placeholder parameters."""
from dataclasses import replace
from pathlib import Path
import numpy as np, pandas as pd
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from hess_model import Params, load_cycle, simulate

OUT = Path(__file__).resolve().parent / "out"
NAVY, RED, SLATE = "#1E3A8A", "#DC2626", "#64748B"
plt.rcParams.update({"font.family": "DejaVu Sans", "axes.spines.top": False, "axes.spines.right": False, "axes.grid": True,
                     "grid.color": "#E2E8F0", "axes.axisbelow": True, "axes.edgecolor": "#94A3B8", "font.size": 11})
p = Params(); base = load_cycle(p=p)

def variant(s):
    """Synthetic riding style: scale the speed profile by s (0.8 calm ... 1.2 aggressive), recompute accel + wheel power."""
    if s == 1.0: return base
    t = base["t"]; v = base["v"] * s; a = np.gradient(v, t)
    F = p.mu * p.mass * 9.81 + 0.5 * p.rho * p.A * p.Cd * v**2 + p.Irot * p.mass * a
    return dict(t=t, v=v, a=a, P=F * v)

rows = []
for name, s in [("Calm (0.8x speed)", 0.8), ("WLTC 2W (1.0x)", 1.0), ("Brisk (1.2x speed)", 1.2)]:
    cyc = variant(s)
    for case in "AC":
        m, _ = simulate(case, p, cyc); rows.append(dict(style=name, case=case, **m))
rs = pd.DataFrame(rows); rs.to_csv(OUT / "robust_riding_styles.csv", index=False)
print(rs[["style", "case", "secs_above_stress_c", "regen_capture_pct", "reuse_pct", "batt_loss_wh"]].round(2).to_string(index=False))

# ---- Monte Carlo over the unknown TVS parameters ----
rng = np.random.default_rng(7); N = 300; mc = []
for i in range(N):
    pw = rng.uniform(300, 1000)
    q = replace(p, p_isg_max=pw, p_conv_max=1.25 * pw, i_chg_c=rng.uniform(1, 4), i_dis_c=rng.uniform(3, 8),
                batt_r0=rng.uniform(0.02, 0.06), eta_chain=rng.uniform(0.5, 0.8), eta_dc=rng.uniform(0.90, 0.97),
                uc_f=0.2 * pw)                                   # sizing rule of thumb: 0.2 F per W of ISG power
    cyc = load_cycle(p=q)
    mA, _ = simulate("A", q, cyc); mC, _ = simulate("C", q, cyc)
    mc.append(dict(isg_w=pw, uc_f=q.uc_f, chg_c=q.i_chg_c, dis_c=q.i_dis_c,
                   secs_A=mA["secs_above_stress_c"], secs_C=mC["secs_above_stress_c"],
                   cap_A=mA["regen_capture_pct"], cap_C=mC["regen_capture_pct"],
                   reuse_A=mA["reuse_pct"], reuse_C=mC["reuse_pct"],
                   loss_A=mA["batt_loss_wh"], loss_C=mC["batt_loss_wh"], soc_end_C=mC["soc_end"]))
d = pd.DataFrame(mc); d.to_csv(OUT / "robust_montecarlo.csv", index=False)
d["loss_change_pct"] = 100 * (d.loss_C - d.loss_A) / d.loss_A; d["cap_gain"] = d.cap_C - d.cap_A; d["reuse_gain"] = d.reuse_C - d.reuse_A; d["secs_cut"] = d.secs_A - d.secs_C
summ = {
    "draws": N,
    "share_reuse_better_pct": 100 * (d.reuse_gain > 0).mean(),
    "share_capture_better_pct": 100 * (d.cap_gain > 0).mean(),
    "share_stress_time_not_worse_pct": 100 * (d.secs_cut >= 0).mean(),
    "reuse_gain_median": d.reuse_gain.median(), "reuse_gain_p10": d.reuse_gain.quantile(.1), "reuse_gain_p90": d.reuse_gain.quantile(.9),
    "cap_gain_median": d.cap_gain.median(), "cap_gain_p10": d.cap_gain.quantile(.1), "cap_gain_p90": d.cap_gain.quantile(.9),
    "secs_A_median": d.secs_A.median(), "secs_C_median": d.secs_C.median(), "secs_C_p90": d.secs_C.quantile(.9),
    "min_reuse_gain": d.reuse_gain.min(), "min_cap_gain": d.cap_gain.min(), "loss_change_median": d.loss_change_pct.median(), "loss_change_p10": d.loss_change_pct.quantile(.1), "loss_change_p90": d.loss_change_pct.quantile(.9),
}
pd.Series(summ).round(2).to_csv(OUT / "robust_montecarlo_summary.csv"); print(pd.Series(summ).round(2).to_string())

fig, ax = plt.subplots(1, 3, figsize=(13, 3.8))
for a_, col, ttl, unit in [(ax[0], "reuse_gain", "Extra wheel energy from recovery", "percentage points"),
                           (ax[1], "cap_gain", "Extra regen captured", "percentage points"),
                           (ax[2], "loss_change_pct", "Battery I2R loss change", "% vs battery only (negative = lower)")]:
    a_.hist(d[col], bins=24, color=NAVY, alpha=.9); a_.axvline(0, color=RED, ls="--", lw=1.2)
    a_.axvline(d[col].median(), color="#0F172A", lw=1.2); a_.set_title(ttl, fontsize=11); a_.set_xlabel(unit)
ax[0].set_ylabel("Number of parameter draws (of 300)")
fig.tight_layout(); fig.savefig(OUT / "fig6_montecarlo.png", dpi=150, bbox_inches="tight"); plt.close(fig)

fig, ax = plt.subplots(1, 3, figsize=(13, 3.6)); order = ["Calm (0.8x speed)", "WLTC 2W (1.0x)", "Brisk (1.2x speed)"]
for a_, (k, ttl) in zip(ax, [("secs_above_stress_c", "Seconds above 2C"), ("regen_capture_pct", "Regen captured (%)"), ("reuse_pct", "Wheel energy from recovered energy (%)")]):
    x = np.arange(3)
    for j, (case, col, lab) in enumerate([("A", SLATE, "Battery only"), ("C", NAVY, "With UC (ours)")]):
        vals = [rs[(rs["style"] == s) & (rs.case == case)][k].iloc[0] for s in order]
        b = a_.bar(x + (j - .5) * .36, vals, .36, color=col, label=lab)
        for r, v_ in zip(b, vals): a_.text(r.get_x() + r.get_width() / 2, v_, f"{v_:.0f}" if k != "reuse_pct" else f"{v_:.1f}", ha="center", va="bottom", fontsize=9)
    a_.set_xticks(x, ["Calm", "WLTC 2W", "Brisk"]); a_.set_title(ttl, fontsize=11); a_.grid(axis="x", visible=False)
ax[0].legend(frameon=False, loc="upper left")
fig.tight_layout(); fig.savefig(OUT / "fig7_riding_styles.png", dpi=150, bbox_inches="tight"); plt.close(fig)
