clc
clear
import casadi.*

Ts = 1; % Sample time

% Load William-Otto reactor model
[sys,par,F] = WilliamOtto(Ts);
d_val = 1.3; % Disturbance Fa

% Initialize WO reactor
u_in = 3;
[xf,exitflag] = solveODE(sys,par,d_val,u_in);

%% Configure EKF

EKF = prepareEKF(sys,Ts);

ny = numel(sys.y);
nxEKF = numel(sys.x);
xk_hat = xf;
uEKF = u_in;
Pk = 1e3.*eye(nxEKF);
Qk = 1e3.*eye(nxEKF);
Rk = 1e0.*eye(ny);
K = 0;

%% Simulation

nIter = 4*3600;
h = waitbar(0,'Simulation in Progress...');

GC.u = u_in(1);
GC.err = 0;
GC.err0 = 0;
Ju_hat = 0;
for sim_k = 1:nIter
    waitbar(sim_k /nIter)
    
    % Gradient Controller
    GC.tauC = 200;
    GC.Kp = 0.1251;
    GC.Ki = 1.564*1e-4;
    
    GC.err = (0 - Ju_hat);
    GC.u = GC.u + GC.Kp*GC.err + GC.Ki*GC.err - GC.Kp*GC.err0;
    GC.err0 = GC.err;
    
     if sim_k>2*3600
        d_val = 1;
     end
    % Plant simulator
    u_in = vertcat(GC.u);
    Fk = F('x0',xf,'p',vertcat(d_val,u_in));
    xf = full(Fk.xf);
    
    % Gradient Estimator
    [xk_hat,Pk] = EKF_estimation(EKF,xf,xk_hat,u_in,Pk,Qk,Rk,d_val);
    Ju_hat = EstJu(EKF,xk_hat,u_in,d_val);
    
    sim.x(:,sim_k) = xf;
    sim.u(:,sim_k) = u_in;
    sim.Ju(:,sim_k) = Ju_hat;
    sim.c(sim_k) = Ju_hat;
    
end
close(h)
%%

figure(12)
hold all
subplot(221)
hold all
plot((sim.x(6,:)))
ylabel('x_G')
grid on
subplot(222)
hold all
% plot(sim.Ju)
plot(sim.c)
ylabel('J_u')
grid on
subplot(224)
hold all
plot((sim.u(1,:)))
ylabel('F_B')
grid on
subplot(223)
hold all
plot((sim.x(7,:)))
ylabel('T_r')
grid on
save('sim_FRTO2','sim')

function Ju_hat = EstJu(EKF,x_hat,uEKF,d_hat)

A = full(EKF.JacAx(x_hat,uEKF,d_hat));
B = full(EKF.JacBu(x_hat,uEKF,d_hat));
C = full(EKF.JacJx(x_hat,uEKF,d_hat));
D = full(EKF.JacJu(x_hat,uEKF,d_hat));
Ju_hat = -C*(A\B) + D;

end
