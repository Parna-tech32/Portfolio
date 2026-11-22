"""app.py - what-if dashboard for the battery + ultracapacitor model.
Run:  streamlit run app.py
"""
from dataclasses import replace
import numpy as np
import pandas as pd
import streamlit as st
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from hess_model import Params, load_cycle, simulate

NAVY, RED, SLATE, SKY = "#1E3A8A", "#DC2626", "#64748B", "#60A5FA"
st.set_page_config(page_title="UC energy recovery - 2W what-if", layout="wide")
st.title("Ultracapacitor energy recovery for a 2W micro-hybrid")
st.caption("Battery only vs. battery + ultracapacitor on the WLTC 2W cycle. "
           "Vehicle data from the open-source 2W EV model; ISG and battery values are placeholders until TVS data is available.")

base = Params()
with st.sidebar:
    st.header("Ultracapacitor")
    uc_f = st.slider("UC size (F)", 10, 300, 75, 5)
    uc_vmax = st.slider("Max voltage (V)", 12.0, 20.0, 16.0, 0.5)
    uc_vmin = st.slider("Min voltage (V)", 4.0, 12.0, 8.0, 0.5)
    st.header("ISG and battery (placeholders)")
    p_isg = st.slider("ISG power limit (W)", 200, 1500, 500, 50)
    chg_c = st.slider("Battery charge acceptance (C)", 0.5, 4.0, 2.0, 0.5)
    dis_c = st.slider("Battery discharge limit (C)", 2.0, 8.0, 5.0, 0.5)
    st.header("Controller")
    case = st.radio("Controller for the UC system", ["C: SOC-aware (ours)", "B: Filter split"], index=0)
    tf = st.slider("Filter time constant (s)", 0.5, 10.0, 2.0, 0.5)
    soft = st.slider("Battery soft limit, discharge (C)", 1.0, 5.0, 2.0, 0.5)
    st.header("Cost (optional)")
    price = st.number_input("UC price per farad at module level (enter from a datasheet)", min_value=0.0, value=0.0, step=0.1)

p = replace(base, uc_f=float(uc_f), uc_vmax=uc_vmax, uc_vmin=uc_vmin, p_isg_max=float(p_isg),
            p_conv_max=1.25 * p_isg, i_chg_c=chg_c, i_dis_c=dis_c, tf=tf, soft_dis_c=soft)
if uc_vmin >= uc_vmax:
    st.error("Min voltage must be below max voltage."); st.stop()


@st.cache_data(show_spinner=False)
def run(p_dict, key):
    q = Params(**p_dict)
    cyc = load_cycle(p=q)
    a, ta = simulate("A", q, cyc)
    h, th = simulate(key, q, cyc)
    return cyc, (a, ta), (h, th)


key = case[0]
from dataclasses import asdict
cyc, (mA, tA), (mH, tH) = run(asdict(p), key)
t = cyc["t"]

c1, c2, c3, c4 = st.columns(4)
def delta(new, old, unit="", inv=False):
    d = new - old
    return f"{d:+.1f}{unit} vs battery only"
c1.metric("Peak battery C-rate", f"{mH['peak_c_rate']:.1f}C", delta(mH['peak_c_rate'], mA['peak_c_rate'], "C"), delta_color="inverse")
c2.metric("Seconds above 2C", f"{mH['secs_above_stress_c']:.0f} s", delta(mH['secs_above_stress_c'], mA['secs_above_stress_c'], " s"), delta_color="inverse")
c3.metric("Regen energy captured", f"{mH['regen_capture_pct']:.0f}%", delta(mH['regen_capture_pct'], mA['regen_capture_pct'], " pts"))
c4.metric("Wheel energy from recovered energy", f"{mH['reuse_pct']:.1f}%", delta(mH['reuse_pct'], mA['reuse_pct'], " pts"))

fig, ax = plt.subplots(3, 1, figsize=(11, 7.2), sharex=True)
ax[0].plot(t, cyc["v"] * 3.6, color=NAVY); ax[0].set_ylabel("Speed (km/h)")
ax[1].plot(t, np.abs(tA["i_bat"]), color=SLATE, lw=1.3, label="Battery only")
ax[1].plot(t, np.abs(tH["i_bat"]), color=NAVY, lw=1.6, label=f"With UC ({key})")
ax[1].set_ylabel("Battery |I| (A)"); ax[1].legend(loc="upper left", frameon=False, ncol=2)
ax[1].set_ylim(0, max(tA["i_bat"].max(), 10) * 1.25)
ax[2].plot(t, tH["v_uc"], color=NAVY)
ax[2].axhline(uc_vmax, color=RED, ls="--", lw=1); ax[2].axhline(uc_vmin, color=RED, ls="--", lw=1)
ax[2].set_ylabel("UC voltage (V)"); ax[2].set_xlabel("Time (s)")
for a in ax:
    a.grid(color="#E2E8F0"); a.spines[["top", "right"]].set_visible(False); a.set_axisbelow(True)
fig.tight_layout()
st.pyplot(fig)

left, right = st.columns(2)
with left:
    st.subheader("Full comparison")
    rows = [("Peak battery current (A)", "peak_i_bat"), ("RMS battery current (A)", "rms_i_bat"), ("Battery I2R loss (Wh)", "batt_loss_wh"),
            ("Battery Ah throughput (Ah)", "ah_throughput"), ("Regen captured (Wh)", "regen_got_wh"), ("Assist delivered (Wh)", "assist_got_wh"),
            ("UC + converter loss (Wh)", "uc_loss_wh")]
    st.dataframe(pd.DataFrame({"Battery only": [mA[k] for _, k in rows], f"With UC ({key})": [mH[k] for _, k in rows]},
                              index=[n for n, _ in rows]).round(2), width="stretch")
with right:
    st.subheader("Cost check")
    if price > 0:
        st.write(f"UC module cost at {uc_f} F: **{price * uc_f:,.0f}** (in the currency of the price you entered).")
        st.write("Compare this with the value of the battery-life and energy benefit before choosing a size.")
    else:
        st.info("Enter a UC price per farad from a supplier datasheet in the sidebar to see the module cost. "
                "No price is assumed here on purpose.")
    st.caption("Wheel energy from recovered energy = recovered assist energy x drivetrain efficiency / wheel traction energy. "
               "It is a displaced-engine-energy proxy, not a measured mileage gain.")
