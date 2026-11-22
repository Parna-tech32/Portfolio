# 6-hour plan, Simulink build and demo guide

Everything here is tested only where stated. The MATLAB Function block code below was NOT run in MATLAB.
Its logic was transcribed line by line into Python (matlab_function_check.py) and matches the model output to
within rounding (largest difference 0.0001 W on battery power). Syntax errors in MATLAB are still possible: fix them
as you paste.

## What goes where

| Tool | Job | Why |
|---|---|---|
| Python (hess_model.py, run_results.py, robustness.py) | Full comparison, sweeps, 300-draw robustness | Already done, results are on the slides |
| Streamlit dashboard (app.py) | Live what-if demo | `streamlit run app.py`, works in any browser |
| Simulink level 1 | Re-implement the controller in Simulink and show it matches Python | Cheap, shows the idea runs in the judges' tool |
| Simulink level 2 (optional) | Power stage: battery, UC, bidirectional converter with current control | Shows the converter can track the UC current command |

Say on the slide only what you built. Slide 11 says "Simulink + Simscape Electrical (next)". If you finish level 1 or 2,
add a screenshot and change "(next)" to "done" for that level.

## Hour-by-hour (6 hours)

| Time | Task |
|---|---|
| 0:00 to 0:30 | Unzip, `pip install -r requirements.txt`, run `python run_results.py` and `streamlit run app.py`. Check the dashboard shows 2.0C, 0 s, 100%, 8.4% at the defaults. |
| 0:30 to 1:00 | If any TVS value is available (ISG power, battery limits), put it in the Params class, rerun `run_results.py` and `robustness.py`, and tell me which numbers changed so the deck can be updated. Otherwise keep the placeholders and say so. |
| 1:00 to 1:45 | Simulink level 1 (steps below). |
| 1:45 to 3:15 | Simulink level 2, only if level 1 matched. Skip it if it is not working by 3:15. |
| 3:15 to 3:45 | Screenshots into slide 11. Fix the "(next)" label. |
| 3:45 to 4:45 | Record a 3-minute demo video as a backup. Rehearse the talk three times with the slide notes. |
| 4:45 to 5:30 | Export a PDF backup of the deck. Check fonts and images on the submission machine. |
| 5:30 to 6:00 | Freeze. No new changes. Submit early. |

## Simulink level 1: controller cross-check (about 45 minutes)

1. In MATLAB, in the folder with `simulink_inputs.csv`:
   ```matlab
   d     = readtable('simulink_inputs.csv');
   reqTS = timeseries(d.req_W,  d.t_s);   % what the ISG asks of the bus (W)
   vTS   = timeseries(d.v_mps,  d.t_s);   % vehicle speed (m/s)
   ```
2. New Simulink model. Settings: Solver = Fixed-step, discrete (no continuous states), step size 1, stop time 1022.
3. Add two From Workspace blocks: data `reqTS` and `vTS`, sample time 1, "interpolate data" off.
4. Add a MATLAB Function block, paste the code below, wire req and v to its inputs.
5. Add To Workspace blocks (format: Timeseries) on each output: `p_bat`, `p_uc`, `v_uc`, `i_bat`.
6. Run, then compare with the Python columns:
   ```matlab
   figure; plot(d.t_s, d.py_v_uc_V, d.t_s, v_uc.Data, '--'); legend('Python','Simulink'); xlabel('Time (s)'); ylabel('UC voltage (V)');
   disp(max(abs(i_bat.Data - d.py_i_bat_A)))   % should be close to 0
   ```
7. What this shows: the controller logic runs in Simulink and gives the same numbers as the Python model. It validates the
   implementation, not the physics. Say exactly that.

### MATLAB Function block code

```matlab
function [p_bat, p_uc, v_uc, i_bat, soc_out] = hess_ctrl(req, v)
dt = 1;                                    % s, same as the drive-cycle sample time
C = 75; Vmax = 16; Vmin = 8; esr = 1.9/C; eta_dc = 0.95; p_conv_max = 625;
Ah = 5; R0 = 0.03; ocv0 = 12; slope = 1; dis_c = 5; chg_c = 2; soft_dis = 2; soft_chg = 1;
Tf = 2; tau_r = 20; p_corr_max = 60; v_ref = 50;
Emax = 0.5*C*Vmax^2; Emin = 0.5*C*Vmin^2;

persistent p_slow E soc
if isempty(p_slow)
    p_slow = 0; E = Emin + 0.5*(Emax - Emin); soc = 0.7;
end

ocv = ocv0 + slope*soc;
i_dis = dis_c*Ah; i_chg = chg_c*Ah;
p_dis_lim = (ocv - R0*i_dis)*i_dis;  p_chg_lim = (ocv + R0*i_chg)*i_chg;

% split: slow part to the battery, UC voltage target by speed
p_slow = p_slow + dt/(Tf + dt)*(req - p_slow);
x = min(max(0.9 - 0.7*(v*3.6)/v_ref, 0.2), 0.9);
e_tar = Emin + x*(Emax - Emin);
corr = min(max((e_tar - E)/tau_r, -p_corr_max), p_corr_max);
p_bat_cmd = p_slow + corr;

% battery guard: soft C-rate limits, then hard limits
sd = soft_dis*Ah; sc = soft_chg*Ah;
p_bat_cmd = min(max(p_bat_cmd, -(ocv + R0*sc)*sc), (ocv - R0*sd)*sd);
p_bat_cmd = min(max(p_bat_cmd, -p_chg_lim), p_dis_lim);
p_uc = min(max(req - p_bat_cmd, -p_conv_max), p_conv_max);

% UC energy limits (two passes so ESR loss is included)
for k = 1:2
    V = max(sqrt(2*E/C), 0.5*Vmin);
    if p_uc >= 0, p_cap = p_uc/eta_dc; else, p_cap = p_uc*eta_dc; end
    dE = -(p_cap + (p_cap/V)^2*esr)*dt;
    if E + dE > Emax
        p_uc = p_uc*max(Emax - E, 0)/max(dE, 1e-9);
    elseif E + dE < Emin
        p_uc = p_uc*max(E - Emin, 0)/max(-dE, 1e-9);
    end
end
V = max(sqrt(2*E/C), 0.5*Vmin);
if p_uc >= 0, p_cap = p_uc/eta_dc; else, p_cap = p_uc*eta_dc; end
E = min(max(E - (p_cap + (p_cap/V)^2*esr)*dt, Emin), Emax);

% battery takes the rest
p_bat = min(max(req - p_uc, -p_chg_lim), p_dis_lim);
i_bat = (ocv - sqrt(max(ocv^2 - 4*R0*p_bat, 0)))/(2*R0);
soc = min(max(soc - i_bat*dt/(3600*Ah), 0), 1);
v_uc = sqrt(2*E/C);  soc_out = soc;
end
```

## Simulink level 2 (optional): power stage

Goal: show the bidirectional converter can follow the UC power command from level 1 while the bus stays near 12 V.
Block names change between releases, so search the Simscape Electrical library browser for them.

1. Battery: a DC voltage source (about 12.7 V) with 0.03 ohm in series, or the library's battery block.
2. UC: the library's supercapacitor block (or a capacitor of 75 F with 25 milliohm series resistance), initial voltage 12 V.
3. Converter: a half-bridge (buck-boost) with an inductor between the UC and the bus, and a PWM generator.
4. Load: a controlled current source on the bus, set to `p_uc / bus voltage`, i.e. the UC share of the ISG power.
5. Control: PI loop on inductor current, reference from the level 1 output.
6. Report: UC current tracking error, bus voltage ripple, and converter efficiency over the cycle. Compare the efficiency
   with the 95% assumed in the model. If it is lower, rerun `robustness.py` with the measured value.

If this does not work by the 3:15 mark, drop it. The deck is complete without it.

## Demo script (3 minutes)

1. Open the dashboard with UC size at 10 F. Point to peak C-rate and regen captured.
2. Slide UC size to 75 F. Say: "peak battery C-rate drops from 5C to 2C, regen captured goes from 36% to 100%."
3. Lower ISG power to 300 W and set battery charge acceptance to 4C. Say: "here the UC matters least, and we show that too."
4. Close on the metrics table. Say the placeholders out loud: "ISG and battery values are placeholders; we tested 300 random sets."

## Likely judge questions and honest answers

| Question | Answer |
|---|---|
| Are the battery and ISG numbers real? | No. They are placeholders in one class. We tested 300 random sets and the UC improved regen captured in every one. We need TVS's real values. |
| Is the UC really needed if the battery accepts 4C? | Then the gain is small (+0.5 points at a 300 W ISG). The map on slide 10 shows exactly where it pays off. |
| Did the speed-based voltage target matter? | A little. Most of the benefit is the UC plus the battery guard (slide 7). |
| What about cost? | Cost scales with farads; we size by ISG power (about 0.2 F per W). We did not assume a price; the dashboard takes a datasheet price. |
| Is the mileage gain 10%? | We do not claim that. Our metric is a displaced-engine-energy proxy. Calibrating to TVS's claim is the next step. |
| Is this validated on hardware? | No. It is a model. The bench test is on the roadmap. |
