"""
hess_model.py - battery vs. battery + ultracapacitor (HESS) model for a 2W micro-hybrid.

Vehicle parameters and the WLTC_2W.csv drive cycle come from the open-source repo
github.com/controlbydeepsa/Dynamic-Modelling-of-2W-EV.

IMPORTANT: every value marked ASSUMED below is a placeholder. Replace it with TVS data
(ISG power, battery limits, converter efficiency) before quoting results.

Sign convention on the 12 V bus:  P > 0 = power delivered to the ISG (assist),
                                  P < 0 = power taken from the ISG (regen).

Cases
  A  battery only (what iGO Assist does today)
  B  battery + UC, low-pass filter split
  C  battery + UC, SOC-aware split (UC energy target depends on speed)
"""
from dataclasses import dataclass, asdict
from pathlib import Path
import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent


@dataclass
class Params:
    # --- vehicle (from the 2W repo) ---
    mass: float = 188.0        # kg, kerb + rider
    mu: float = 0.005          # rolling resistance
    rho: float = 1.25          # air density kg/m3
    A: float = 0.6             # frontal area m2
    Cd: float = 0.7
    Irot: float = 1.04         # rotational inertia factor
    # --- ISG / drivetrain (ASSUMED) ---
    p_isg_max: float = 500.0   # W, ISG electrical power limit (regen and assist)
    eta_chain: float = 0.70    # wheel <-> bus efficiency (ISG + drivetrain)
    a_assist: float = 0.3      # m/s2, assist only while accelerating harder than this
    # --- battery (ASSUMED) ---
    batt_ah: float = 5.0       # Ah (12 V, 5 Ah per TVS iGO Assist description)
    batt_r0: float = 0.03      # ohm, pack resistance
    ocv0: float = 12.0         # V at 0 % SOC
    ocv_slope: float = 1.0     # V per unit SOC
    i_dis_c: float = 5.0       # C-rate allowed for discharge
    i_chg_c: float = 2.0       # C-rate allowed for charge (regen acceptance)
    soc0: float = 0.7
    # --- ultracapacitor + converter ---
    uc_f: float = 126.0        # F (from our sizing script)
    uc_vmax: float = 16.0
    uc_vmin: float = 8.0
    uc_esr_k: float = 1.9      # ASSUMED: ESR [ohm] = uc_esr_k / C[F]
    p_conv_max: float = 1000.0 # W, converter rating (ASSUMED)
    eta_dc: float = 0.95       # converter efficiency (ASSUMED)
    uc_soc0: float = 0.5       # start at this fraction of the usable window
    # --- controller ---
    tf: float = 2.0            # s, low-pass time constant of the filter split
    tau_r: float = 20.0        # s, SOC regulator time constant (case C)
    p_corr_max: float = 60.0   # W, max battery power used to re-centre the UC (case C)
    v_ref_kmh: float = 50.0    # km/h, speed at which the UC target is lowest (case C)
    soft_dis_c: float = 2.0    # C-rate the controller tries to keep the battery under (discharge, case C)
    soft_chg_c: float = 1.0    # same for charging (case C)
    stress_c: float = 2.0      # metric: seconds spent above this C-rate


def load_cycle(path=None, p: Params = None):
    p = p or Params()
    path = Path(path) if path else HERE / "WLTC_2W.csv"
    c = pd.read_csv(path).dropna().to_numpy(dtype=float)
    t, v, a = c[:, 0], c[:, 1] / 3.6, c[:, 2]
    F = p.mu * p.mass * 9.81 + 0.5 * p.rho * p.A * p.Cd * v**2 + p.Irot * p.mass * a
    return dict(t=t, v=v, a=a, P=F * v)


def _batt_current(P, ocv, r):
    """Battery current (A, + = discharge) for terminal power P (W)."""
    disc = max(ocv * ocv - 4.0 * r * P, 0.0)
    return (ocv - np.sqrt(disc)) / (2.0 * r)


def simulate(case, p: Params, cyc=None):
    cyc = cyc or load_cycle(p=p)
    t, v, a, Pw = cyc["t"], cyc["v"], cyc["a"], cyc["P"]
    n = len(t)
    C = p.uc_f
    esr = p.uc_esr_k / max(C, 1e-9)
    Emax, Emin = 0.5 * C * p.uc_vmax**2, 0.5 * C * p.uc_vmin**2
    use_uc = case in ("B", "C") and C > 0

    soc = p.soc0
    E = Emin + p.uc_soc0 * (Emax - Emin)
    p_slow = 0.0
    pool = 0.0                                   # J of reusable recovered energy

    keys = ["req", "p_bat", "p_uc", "i_bat", "v_uc", "soc", "delivered", "uc_loss", "v_bat"]
    ts = {k: np.zeros(n) for k in keys}
    regen_req = regen_got = assist_req = assist_got = 0.0
    batt_loss = ah_thru = uc_loss_j = 0.0

    for k in range(n):
        dt = (t[k + 1] - t[k]) if k < n - 1 else 1.0
        ocv = p.ocv0 + p.ocv_slope * soc
        i_dis = p.i_dis_c * p.batt_ah
        i_chg = p.i_chg_c * p.batt_ah
        p_dis_lim = (ocv - p.batt_r0 * i_dis) * i_dis
        p_chg_lim = (ocv + p.batt_r0 * i_chg) * i_chg

        # ---- what the powertrain asks of the bus ----
        P = Pw[k]
        req = 0.0
        if P < 0 and v[k] > 1.0:
            req = -min(p.eta_chain * (-P), p.p_isg_max)
        elif P > 0 and a[k] > p.a_assist and pool > 0:
            req = min(p.p_isg_max, P / p.eta_chain)

        # ---- controller: how the request is split ----
        if use_uc:
            p_slow += dt / (p.tf + dt) * (req - p_slow)
            p_bat_cmd = p_slow
            if case == "C":
                x = np.clip(0.9 - 0.7 * (v[k] * 3.6) / p.v_ref_kmh, 0.2, 0.9)
                e_tar = Emin + x * (Emax - Emin)
                p_bat_cmd += np.clip((e_tar - E) / p.tau_r, -p.p_corr_max, p.p_corr_max)
                # battery protection: UC takes whatever would push the battery past the soft C-rates
                si_d, si_c = p.soft_dis_c * p.batt_ah, p.soft_chg_c * p.batt_ah
                p_bat_cmd = np.clip(p_bat_cmd, -(ocv + p.batt_r0 * si_c) * si_c, (ocv - p.batt_r0 * si_d) * si_d)
            p_bat_cmd = np.clip(p_bat_cmd, -p_chg_lim, p_dis_lim)
            p_uc = np.clip(req - p_bat_cmd, -p.p_conv_max, p.p_conv_max)

            # UC energy limits (two passes, so ESR loss is included)
            for _ in range(2):
                V = max(np.sqrt(2 * E / C), 0.5 * p.uc_vmin)
                p_cap = p_uc / p.eta_dc if p_uc >= 0 else p_uc * p.eta_dc
                dE = -(p_cap + (p_cap / V) ** 2 * esr) * dt
                if E + dE > Emax:
                    p_uc *= max(Emax - E, 0.0) / max(dE, 1e-9)
                elif E + dE < Emin:
                    p_uc *= max(E - Emin, 0.0) / max(-dE, 1e-9)
            V = max(np.sqrt(2 * E / C), 0.5 * p.uc_vmin)
            p_cap = p_uc / p.eta_dc if p_uc >= 0 else p_uc * p.eta_dc
            conv_loss = abs(abs(p_uc) - abs(p_cap))
            esr_loss = (p_cap / V) ** 2 * esr
            E = float(np.clip(E - (p_cap + esr_loss) * dt, Emin, Emax))
            uc_loss_j += (conv_loss + esr_loss) * dt
            ts["uc_loss"][k] = conv_loss + esr_loss
        else:
            p_uc = 0.0

        # ---- battery takes the rest, within its limits ----
        p_bat = float(np.clip(req - p_uc, -p_chg_lim, p_dis_lim))
        i_b = _batt_current(p_bat, ocv, p.batt_r0)
        soc = float(np.clip(soc - i_b * dt / (3600 * p.batt_ah), 0.0, 1.0))
        batt_loss += i_b**2 * p.batt_r0 * dt
        ah_thru += abs(i_b) * dt / 3600

        delivered = p_bat + p_uc
        pool = max(pool - delivered * dt, 0.0)
        if req < 0:
            regen_req += -req * dt
            regen_got += max(-delivered, 0.0) * dt
        elif req > 0:
            assist_req += req * dt
            assist_got += max(delivered, 0.0) * dt

        ts["req"][k], ts["p_bat"][k], ts["p_uc"][k] = req, p_bat, p_uc
        ts["i_bat"][k], ts["v_uc"][k] = i_b, np.sqrt(2 * E / C) if C > 0 else 0.0
        ts["soc"][k], ts["delivered"][k] = soc, delivered
        ts["v_bat"][k] = ocv - i_b * p.batt_r0

    Et = np.trapezoid(np.maximum(Pw, 0), t) / 3600
    Eb = np.trapezoid(np.maximum(-Pw, 0), t) / 3600
    i = ts["i_bat"]
    m = dict(
        peak_i_bat=float(np.abs(i).max()),
        peak_c_rate=float(np.abs(i).max() / p.batt_ah),
        secs_above_stress_c=float(np.sum(np.abs(i) > p.stress_c * p.batt_ah * 1.001)),
        rms_i_bat=float(np.sqrt(np.mean(i**2))),
        batt_loss_wh=batt_loss / 3600,
        ah_throughput=ah_thru,
        regen_req_wh=regen_req / 3600,
        regen_got_wh=regen_got / 3600,
        regen_capture_pct=100 * regen_got / regen_req if regen_req else 0.0,
        assist_req_wh=assist_req / 3600,
        assist_got_wh=assist_got / 3600,
        assist_served_pct=100 * assist_got / assist_req if assist_req else 0.0,
        reuse_pct=100 * p.eta_chain * (assist_got / 3600) / Et,   # engine energy displaced
        uc_loss_wh=uc_loss_j / 3600,
        soc_end=float(ts["soc"][-1]),
        wheel_traction_wh=Et, wheel_braking_wh=Eb,
    )
    return m, ts


def compare(p: Params = None, cyc=None, cases=("A", "B", "C")):
    p = p or Params()
    cyc = cyc or load_cycle(p=p)
    out = {c: simulate(c, p, cyc) for c in cases}
    return out, cyc


if __name__ == "__main__":
    res, _ = compare()
    df = pd.DataFrame({c: m for c, (m, _) in res.items()}).round(2)
    print(df.to_string())
