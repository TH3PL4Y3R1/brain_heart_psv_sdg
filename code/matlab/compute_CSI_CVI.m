function [CSI_out, CVI_out, t_out] = compute_CSI_CVI(RR, t_RR, wind)
% COMPUTE_CSI_CVI
% Builds time‑varying CSI and CVI series from NON‑interpolated inter‑beat
% intervals (RR) using sliding Poincaré descriptors. The output is resampled
% at 4 Hz for convenient alignment with other signals.
%
% Inputs
% - RR   : vector of inter‑beat intervals (seconds), non‑interpolated
% - t_RR : timestamps (seconds) for each RR value (same length as RR)
% - wind : window length in seconds for the time‑varying estimation (e.g., 15)
%
% Outputs
% - CSI_out, CVI_out : scaled indices sampled uniformly at 4 Hz
% - t_out            : time vector (seconds) corresponding to the outputs

% Define target sampling for the uniformly sampled output time base
Fs = 4; % Hz (time step = 0.25 s)
time = t_RR(1) : 1 / Fs : t_RR(end);

% 1) Global Poincaré descriptors
%    Compute SD1/SD2 on the whole RR series to establish a baseline.
sd = diff(RR);
SD01 = sqrt(0.5 * std(sd)^2);                     % baseline SD1
SD02 = sqrt(2*(std(RR)^2) - (0.5 * std(sd)^2));   % baseline SD2

% 2) Time‑varying SD1/SD2 using a sliding window over t_RR
t1 = time(1);
t2 = t1 +  wind;                 % first window end
ixs = find(t_RR > t2);           % indices marking possible window ends
nt  = length(ixs) - 1;           % number of windows

SD1 = zeros(1, nt);
SD2 = zeros(1, nt);
t_C = zeros(1, nt);              % center (here: end) time of each window

for k = 1:nt
    i = ixs(k);
    t2 = t_RR(i);                % window end time
    t1 = t_RR(i) - wind;         % window start time
    ix = find(t_RR >= t1 & t_RR <= t2);

    sd = diff(RR(ix));
    SD1(k) = sqrt(0.5 * std(sd)^2);
    SD2(k) = sqrt(2*(std(RR(ix))^2) - (0.5 * std(sd)^2));

    t_C(k) = t2;                 % choose end time as the window timestamp
end

% 3) Re‑center SD1/SD2 to their global baselines to stabilize magnitudes
SD1 = SD1 - mean(SD1) + SD01;
SD2 = SD2 - mean(SD2) + SD02;

% 4) Map SD1/SD2 to CVI/CSI (scaled). Alternatives are left below.
% Classic alternatives:
% CVI = SD1 .* SD2 * 100;   % multiplicative form
% CSI = SD2 ./ SD1;         % ratio form

CVI = SD1 * 10;             % scaled SD1 (vagal surrogate)
CSI = SD2 * 10;             % scaled SD2 (sympathetic surrogate)

% 5) Interpolate to a uniform 4 Hz time grid for downstream modeling
t_out   = t_C(1) : 1 / Fs : t_C(end);
CVI_out = interp1(t_C, CVI, t_out, 'Spline');
CSI_out = interp1(t_C, CSI, t_out, 'Spline');

end