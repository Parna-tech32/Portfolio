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
