%% Simulink level 1: controller cross-check (builds, runs and compares automatically)
% Put this file, hess_ctrl.m and simulink_inputs.csv in one folder, then run:  build_level1_model
% Not run in MATLAB by the author: if a block parameter name errors in your release, fix that line.

clear; clc; bdclose all;
here = fileparts(mfilename('fullpath'));  if isempty(here), here = pwd; end
cd(here);

%% 1. Load inputs (guide step 1)
d     = readtable('simulink_inputs.csv');
reqTS = timeseries(d.req_W, d.t_s);   % ISG request on the bus (W)
vTS   = timeseries(d.v_mps, d.t_s);   % vehicle speed (m/s)
assignin('base','reqTS',reqTS);  assignin('base','vTS',vTS);  assignin('base','d',d);

%% 2. Model + solver settings (step 2)
mdl = 'hess_level1';
new_system(mdl); open_system(mdl);
set_param(mdl,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
    'FixedStep','1','StartTime','0','StopTime','1022');

%% 3. Source blocks (step 3)
add_block('simulink/Sources/From Workspace',[mdl '/req'],'Position',[40 40 120 70], ...
    'VariableName','reqTS','SampleTime','1','Interpolate','off','OutputAfterFinalValue','Holding final value');
add_block('simulink/Sources/From Workspace',[mdl '/v'],'Position',[40 120 120 150], ...
    'VariableName','vTS','SampleTime','1','Interpolate','off','OutputAfterFinalValue','Holding final value');

%% 4. MATLAB Function block with the controller (step 4)
blk = [mdl '/hess_ctrl'];
add_block('simulink/User-Defined Functions/MATLAB Function',blk,'Position',[220 30 340 190]);
rt    = sfroot;
chart = rt.find('-isa','Stateflow.EMChart','Path',blk);
chart.Script = fileread('hess_ctrl.m');
% Inputs/outputs are scalar doubles by inference; ports now exist in the order of the signature.

add_line(mdl,'req/1','hess_ctrl/1');
add_line(mdl,'v/1',  'hess_ctrl/2');

%% 5. To Workspace blocks, Timeseries format (step 5)
outs = {'p_bat','p_uc','v_uc','i_bat','soc_out'};
for k = 1:numel(outs)
    tw = [mdl '/tw_' outs{k}];
    add_block('simulink/Sinks/To Workspace',tw,'Position',[440 30+45*(k-1) 520 60+45*(k-1)], ...
        'VariableName',outs{k},'SaveFormat','Timeseries','SampleTime','-1');
    add_line(mdl,sprintf('hess_ctrl/%d',k),sprintf('tw_%s/1',outs{k}));
end
save_system(mdl);

%% 6. Run and compare with Python columns (step 6)
sim(mdl);   % To Workspace variables land in the base workspace

cmp = {'p_bat','py_p_bat_W'; 'p_uc','py_p_uc_W'; 'v_uc','py_v_uc_V'; 'i_bat','py_i_bat_A'; 'soc_out','py_soc'};
fprintf('\nMax |Simulink - Python| per signal\n');
for k = 1:size(cmp,1)
    s = evalin('base',cmp{k,1});
    fprintf('  %-8s %.3g\n', cmp{k,1}, max(abs(squeeze(s.Data) - d.(cmp{k,2}))));
end

v_uc  = evalin('base','v_uc');
i_bat = evalin('base','i_bat');
figure('Name','Level 1 cross-check');
subplot(2,1,1);
plot(d.t_s, d.py_v_uc_V, d.t_s, squeeze(v_uc.Data), '--','LineWidth',1.2);
legend('Python','Simulink'); xlabel('Time (s)'); ylabel('UC voltage (V)'); grid on;
subplot(2,1,2);
plot(d.t_s, d.py_i_bat_A, d.t_s, squeeze(i_bat.Data), '--','LineWidth',1.2);
legend('Python','Simulink'); xlabel('Time (s)'); ylabel('Battery current (A)'); grid on;

fprintf('\nThis validates the implementation (same logic, same numbers), not the physics.\n');
