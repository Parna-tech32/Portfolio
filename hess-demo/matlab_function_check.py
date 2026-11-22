"""Line-by-line Python transcription of the MATLAB Function block in SIMULINK_GUIDE.md, checked against the model output."""
import numpy as np, pandas as pd
d = pd.read_csv("simulink_inputs.csv")
dt=1.0; C=75.0; Vmax=16.0; Vmin=8.0; esr=1.9/C; eta_dc=0.95; p_conv_max=625.0
Ah=5.0; R0=0.03; ocv0=12.0; slope=1.0; dis_c=5.0; chg_c=2.0; soft_dis=2.0; soft_chg=1.0
Tf=2.0; tau_r=20.0; p_corr_max=60.0; v_ref=50.0
Emax=0.5*C*Vmax**2; Emin=0.5*C*Vmin**2
clip=lambda x,lo,hi: min(max(x,lo),hi)
p_slow=0.0; E=Emin+0.5*(Emax-Emin); soc=0.7; out=[]
for req,v in zip(d.req_W,d.v_mps):
    ocv=ocv0+slope*soc; i_dis=dis_c*Ah; i_chg=chg_c*Ah
    p_dis_lim=(ocv-R0*i_dis)*i_dis; p_chg_lim=(ocv+R0*i_chg)*i_chg
    p_slow=p_slow+dt/(Tf+dt)*(req-p_slow)
    x=clip(0.9-0.7*(v*3.6)/v_ref,0.2,0.9); e_tar=Emin+x*(Emax-Emin)
    corr=clip((e_tar-E)/tau_r,-p_corr_max,p_corr_max); p_bat_cmd=p_slow+corr
    sd=soft_dis*Ah; sc=soft_chg*Ah
    p_bat_cmd=clip(p_bat_cmd,-(ocv+R0*sc)*sc,(ocv-R0*sd)*sd)
    p_bat_cmd=clip(p_bat_cmd,-p_chg_lim,p_dis_lim)
    p_uc=clip(req-p_bat_cmd,-p_conv_max,p_conv_max)
    for k in range(2):
        V=max(np.sqrt(2*E/C),0.5*Vmin)
        p_cap=p_uc/eta_dc if p_uc>=0 else p_uc*eta_dc
        dE=-(p_cap+(p_cap/V)**2*esr)*dt
        if E+dE>Emax: p_uc=p_uc*max(Emax-E,0)/max(dE,1e-9)
        elif E+dE<Emin: p_uc=p_uc*max(E-Emin,0)/max(-dE,1e-9)
    V=max(np.sqrt(2*E/C),0.5*Vmin)
    p_cap=p_uc/eta_dc if p_uc>=0 else p_uc*eta_dc
    E=clip(E-(p_cap+(p_cap/V)**2*esr)*dt,Emin,Emax)
    p_bat=clip(req-p_uc,-p_chg_lim,p_dis_lim)
    i_bat=(ocv-np.sqrt(max(ocv**2-4*R0*p_bat,0)))/(2*R0)
    soc=clip(soc-i_bat*dt/(3600*Ah),0,1)
    out.append((p_bat,p_uc,np.sqrt(2*E/C),i_bat))
o=np.array(out)
print("max |diff| p_bat W:",np.abs(o[:,0]-d.py_p_bat_W).max(),"| v_uc V:",np.abs(o[:,2]-d.py_v_uc_V).max(),"| i_bat A:",np.abs(o[:,3]-d.py_i_bat_A).max())
