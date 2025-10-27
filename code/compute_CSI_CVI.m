function [CSI_out, CVI_out, t_out] = compute_CSI_CVI(RR, t_RR, wind)
% COMPUTE_CSI_CVI Compute time-varying CSI and CVI from RR intervals.
%
% Inputs
% - RR   : vector of inter-beat intervals (IBI, seconds), non-interpolated
% - t_RR : vector of timestamps (seconds) for each RR value (same length as RR)
% - wind : window length in seconds for time-varying estimation (e.g., 15)
%
% Outputs
% - CSI_out : time-aligned Cardiac Sympathetic Index (scaled) on a uniform grid
% - CVI_out : time-aligned Cardiac Vagal Index (scaled) on a uniform grid
% - t_out   : time vector (seconds) for CSI_out and CVI_out (uniform sampling)
%
% Method (high-level)
% 1) Compute global Poincaré descriptors SD1 and SD2 from RR to establish baseline.
% 2) Slide a window of length `wind` over t_RR and compute SD1(t), SD2(t).
% 3) Remove the mean from SD1(t) and SD2(t) and re-center them to the global baseline.
% 4) Scale the series to obtain CSI and CVI (here both scaled by 10 for numeric stability).
% 5) Interpolate CSI and CVI to a fixed uniform time grid for downstream modeling.
%
% Notes
% - Classic definitions sometimes use: CVI = SD1 .* SD2, CSI = SD2 ./ SD1.
%   Those are kept below as commented alternatives. This implementation scales
%   both SD1 and SD2 by a factor of 10 to stabilize magnitudes for later ARX modeling.
% - Sampling for the output time grid is fixed at Fs = 4 Hz.

Fs = 4;
time = t_RR(1) : 1 / Fs : t_RR(end);

%% first poincare plot

sd=diff(RR); 
SD01 = sqrt(0.5*std(sd)^2);
SD02 = sqrt(2*(std(RR)^2)-(0.5*std(sd)^2));

%% time varying SD
t1 = time(1);
t2 = t1 +  wind;
ixs = find(t_RR > t2);
nt = length(ixs)-1;

SD1 = zeros(1,nt);
SD2 = zeros(1,nt);
t_C = zeros(1,nt);

for k = 1 : nt
    i = ixs(k); 

    t2 = t_RR(i);
    t1 = t_RR(i)-wind;
    ix = find(t_RR >= t1 & t_RR<= t2);
    
    sd=diff(RR(ix)); 
    SD1(k) = sqrt(0.5*std(sd)^2);
    SD2(k) = sqrt(2*(std(RR(ix))^2)-(0.5*std(sd)^2));

    t_C(k) = t2;

end

SD1 = SD1 - mean(SD1) + SD01;
SD2 = SD2 - mean(SD2) + SD02;

% CVI = SD1.*SD2 * 100;
% CSI = SD2./SD1;


CVI = SD1 * 10;
CSI = SD2 * 10;

%%
t_out = t_C(1) : 1 / Fs : t_C(end);
CVI_out = interp1(t_C, CVI, t_out, 'Spline');
CSI_out = interp1(t_C, CSI, t_out, 'Spline');

end