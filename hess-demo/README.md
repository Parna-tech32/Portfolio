# UC energy recovery for a 2W micro-hybrid: model and dashboard

Files
- hess_model.py   core model: vehicle, battery (Thevenin), UC with ESR, buck-boost efficiency, 3 controllers
- run_results.py  runs the comparison and sweeps, writes charts and CSVs to ./out
- app.py          Streamlit what-if dashboard
- WLTC_2W.csv     drive cycle from github.com/controlbydeepsa/Dynamic-Modelling-of-2W-EV

Run
    pip install numpy pandas matplotlib streamlit
    python run_results.py        # charts + CSVs in ./out
    streamlit run app.py         # dashboard in the browser

Cases: A battery only | B battery + UC, low-pass filter split | C battery + UC, SOC-aware split with a battery C-rate soft limit.

Placeholders (replace with TVS data, they are in the Params class): ISG power limit, drivetrain efficiency, battery
resistance and C-rate limits, converter rating and efficiency, UC ESR. Results change with all of them; see
out/fig4_where_uc_helps.png and out/sweep_*.csv.

Metric note: "wheel energy from recovered energy" = assist energy x drivetrain efficiency / wheel traction energy.
It is a proxy for engine energy displaced, not a measured mileage gain.

Added for round 2
- robustness.py          riding-style variants + 300-draw Monte Carlo over the placeholder parameters (charts in ./out)
- simulink_inputs.csv    drive-cycle request profile and Python reference outputs, for cross-checking a Simulink model
- matlab_function_check.py  Python transcription of the Simulink MATLAB Function block, checked against the model
- SIMULINK_GUIDE.md      6-hour plan and step-by-step Simulink build
