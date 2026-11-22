# Ultracapacitor Energy Recovery for 2W Micro-Hybrids

### Hybrid Energy Storage Simulation | Python · Streamlit · Energy Management

An ultracapacitor-based energy recovery system designed for two-wheeler micro-hybrid powertrains. The project explores how a small ultracapacitor can improve regenerative braking energy capture, reduce battery current stress, and support short-duration acceleration assistance by handling high-power transients.

The simulation uses the WLTC 2W drive cycle to compare a battery-only system against hybrid battery–ultracapacitor configurations with different energy management strategies.

🔗 **Interactive Dashboard:** https://hess-energy-simulation.streamlit.app

---

## Overview

Conventional battery-based regenerative braking systems are limited by battery charge acceptance. During braking, high-power energy pulses may exceed the battery's ability to absorb energy, resulting in regenerative energy being lost.

This project introduces an ultracapacitor as a high-power buffer alongside the existing 12 V battery. The ultracapacitor handles rapid charging and discharging, while the battery primarily supplies and absorbs slower energy demands.

The objective is to improve energy recovery while limiting battery stress without unnecessarily increasing ultracapacitor capacity.

## System Architecture

The proposed system consists of:

- **12 V battery:** Supplies steady energy and handles slower power demands.
- **Ultracapacitor (UC):** Absorbs regenerative braking pulses and supplies short-duration acceleration assistance.
- **Bidirectional buck-boost converter:** Manages energy transfer between the ultracapacitor and the 12 V bus.
- **ISG (Integrated Starter Generator):** Provides regenerative braking and motor assistance.
- **Energy management controller:** Controls power sharing based on vehicle speed, battery current limits, and UC voltage.

## Key Features

- Battery-only vs. hybrid battery–ultracapacitor comparison
- Ultracapacitor sizing based on ISG power requirements
- Battery charge and discharge C-rate protection
- Regenerative braking energy recovery analysis
- Energy management using filtered power splitting and battery current guards
- Ultracapacitor voltage pre-conditioning based on vehicle speed
- Riding-style analysis across different drive-cycle conditions
- Monte Carlo robustness analysis across 300 parameter combinations
- Interactive Streamlit dashboard for real-time parameter exploration
- Simulation plots, performance metrics, and CSV-based results

## Energy Management Strategy

The controller manages the battery and ultracapacitor according to the power demand and available energy.

1. **Power request:** Detects braking and acceleration events to determine regenerative or assist power.
2. **Power splitting:** Separates slower power demand for the battery from high-power transients.
3. **Battery protection:** Limits battery charge and discharge current to reduce high C-rate operation.
4. **Ultracapacitor buffering:** Assigns excess regenerative energy and short-duration assist demand to the UC.
5. **Voltage pre-conditioning:** Adjusts the UC target voltage based on vehicle speed to reserve capacity for braking or acceleration.

## Ultracapacitor Sizing

The ultracapacitor is sized according to the power that the ISG can realistically deliver rather than the total wheel-level braking energy.

The model evaluates UC capacitance requirements while considering:

- ISG power limits
- UC operating voltage window
- Regenerative braking capture
- Battery current constraints
- Converter efficiency

The simulation explores a sizing rule of approximately **0.2 F per watt of ISG power**, with the required converter rating set to approximately 1.25 times the ISG power.

## Simulation & Analysis

The model is evaluated using the **WLTC 2W drive cycle** and compares:

- Battery-only energy recovery
- Battery–UC hybrid system
- Different energy management controllers
- Different UC capacitance values
- ISG power and battery charge acceptance variations
- Calm, WLTC, and brisk riding profiles

### Robustness Analysis

A Monte Carlo analysis evaluates 300 randomized parameter combinations, including ISG power, battery limits, resistance, drivetrain efficiency, and converter efficiency, to investigate whether the benefits of the ultracapacitor remain consistent under uncertain system parameters.

## Key Results

The base-case simulation demonstrates:

- **Regenerative energy capture:** 36% to 100%
- **Peak battery C-rate:** 5C to 2C
- **Battery current stress:** Reduced high-current operation
- **Battery I²R losses:** Approximately 61% reduction
- **Recovered wheel energy contribution:** 3.3% to 8.4%

The robustness study also indicates improvement in regenerative energy capture and recovered-energy contribution across the tested parameter sets.

*These are simulation results based on placeholder battery and ISG parameters, not experimentally measured vehicle performance.*

## Interactive Dashboard

The Streamlit application allows users to explore the system through configurable parameters, including:

- Ultracapacitor size
- ISG power
- Battery charge acceptance
- Battery discharge limits
- Controller selection

The dashboard provides time-series visualizations, battery current analysis, UC voltage behavior, performance comparisons, and cost estimation based on user-provided ultracapacitor pricing.

## Technologies Used

- Python
- Streamlit
- NumPy
- Pandas
- Matplotlib
- CSV-based drive-cycle data
- Monte Carlo simulation
- Energy storage and powertrain modeling

## Project Structure

```text
hess-demo/
├── app.py
├── hess_model.py
├── robustness.py
├── run_results.py
├── matlab_function_check.py
├── simulink_inputs.csv
├── requirements.txt
├── SIMULINK_GUIDE.md
├── WLTC_2W.csv
├── hess_demo/
│   ├── app.py
│   ├── hess_model.py
│   ├── run_results.py
│   ├── requirements.txt
│   └── out/
│       ├── dashboard.png
│       ├── fig1_timeseries.png
│       ├── fig2_metrics.png
│       ├── fig3_uc_size.png
│       ├── fig4_where_uc_helps.png
│       └── ...
└── out/
    ├── simulation plots
    ├── comparison metrics
    ├── sweep results
    └── robustness analysis
```

## Future Work

- Replace placeholder ISG and battery parameters with manufacturer data
- Calibrate the baseline model against real vehicle performance
- Validate the power stage using Simulink and Simscape Electrical
- Prototype the battery–ultracapacitor converter system
- Conduct hardware testing using ultracapacitor cells and a motor setup

---

**Project Focus:** Regenerative energy recovery · Hybrid energy storage · Battery protection · Power electronics · Energy management · Two-wheeler electrification
