% SYNTHETIC_TEST_BRAIN_HEART
% ---------------------------------------------------------------
% Generates synthetic inter‑beat intervals (RR), computes time‑resolved
% CSI/CVI via the existing function `compute_CSI_CVI`, builds synthetic EEG
% band‑power channels, injects weak heart→brain coupling, and runs
% `model_psv_sdg` to obtain directional coupling estimates.
%
% You can modify parameters (Fs, T_sec, wind) to explore behavior.
% This script is self‑contained and does NOT alter the original functions.
%
% REQUIREMENTS:
%   - System Identification Toolbox (for ARX) used inside model_psv_sdg.
%   - Functions on MATLAB path: compute_CSI_CVI.m, model_psv_sdg.m
%
% OUTPUTS (printed / plotted):
%   - Lengths of RR, CSI/CVI vectors
%   - Plots of RR, CSI/CVI, EEG channels, and estimated couplings.
% ---------------------------------------------------------------

%% Parameter configuration
Fs      = 4;        % Sampling rate for EEG band‑power time series (Hz)
T_sec   = 600;      % Total duration (seconds)
wind    = 15;       % Window length (seconds) used by both CSI/CVI and model
nCh     = 5;        % Number of synthetic EEG band‑power channels
rng(12);            % Reproducibility seed

%% 1) Generate synthetic RR (IBI) series with physiological variability
% Heart rate model: HR(t) = HR0 + LF + HF + noise
% LF ~ 0.1 Hz (sympathetic modulation), HF ~ 0.25 Hz (respiratory vagal)
HR0   = 1.0;        % baseline heart rate ~ 60 bpm
A_lf  = 0.15;       % low‑frequency amplitude
A_hf  = 0.10;       % high‑frequency (respiratory) amplitude
f_lf  = 0.10;       % Hz
f_hf  = 0.25;       % Hz
noise_sd = 0.02;    % small random jitter

RR      = [];       % inter‑beat intervals (seconds)
t_RR    = [];       % timestamp at each beat (seconds)

current_t = 0;
while current_t < T_sec
    HR_t = HR0 + A_lf * sin(2*pi*f_lf*current_t) + A_hf * sin(2*pi*f_hf*current_t) ...
                 + noise_sd * randn();
    HR_t = max(HR_t, 0.5); % avoid unrealistically low HR
    ibi  = 1 / HR_t;       % IBI = inverse of instantaneous HR
    RR(end+1)   = ibi;     %#ok<*AGROW>
    current_t   = current_t + ibi;
    t_RR(end+1) = current_t; % Associate RR value to the END time (consistent with compute_CSI_CVI)
end

% Trim if overshoot beyond T_sec
if t_RR(end) > T_sec
    t_RR(end) = T_sec;
end

fprintf('Generated %d RR intervals, last time = %.2f s\n', numel(RR), t_RR(end));

%% 2) Compute time‑varying CSI/CVI using existing function
% The function internally outputs series sampled at 4 Hz (Fs=4 fixed inside).
[CSI_series, CVI_series, t_CSI_CVI] = compute_CSI_CVI(RR, t_RR, wind);

fprintf('CSI/CVI computed: length = %d (time range %.2f–%.2f s)\n', ...
    numel(CSI_series), t_CSI_CVI(1), t_CSI_CVI(end));

%% 3) Construct synthetic EEG band‑power channels
% Each channel: baseline + slow drift + noise. Add weak coupling segment
% by injecting scaled CSI/CVI in overlapping region to make H→B detectable.

time_eeg = 0 : 1/Fs : T_sec; % EEG time base
Nt = numel(time_eeg);
EEG_comp = zeros(nCh, Nt);

for ch = 1:nCh
    % Distinct baseline and slow drift frequency per channel
    base     = 1 + 0.2*(ch-1);
    drift_f  = 0.005 + 0.002*(ch-1);  % very low frequency drift
    drift    = 0.5 * sin(2*pi*drift_f*time_eeg);
    noise    = 0.1 * randn(1, Nt);
    EEG_comp(ch,:) = base + drift + noise;
end

% Overlap region for coupling injection
t_start_overlap = max([time_eeg(1), t_CSI_CVI(1)]);
t_end_overlap   = min([time_eeg(end), t_CSI_CVI(end)]);
mask_overlap    = time_eeg >= t_start_overlap & time_eeg <= t_end_overlap;

% Interpolate CSI/CVI onto EEG time for injection
CSI_on_eeg = interp1(t_CSI_CVI, CSI_series, time_eeg(mask_overlap), 'linear');
CVI_on_eeg = interp1(t_CSI_CVI, CVI_series, time_eeg(mask_overlap), 'linear');

% Inject small coupling into first two channels (synthetic heart→brain influence)
EEG_comp(1,mask_overlap) = EEG_comp(1,mask_overlap) + 0.15 * CSI_on_eeg; % sympathetic influence
EEG_comp(2,mask_overlap) = EEG_comp(2,mask_overlap) + 0.15 * CVI_on_eeg; % vagal influence

%% 4) Run model_psv_sdg to estimate directional couplings (if ARX available)
if isempty(which('arx'))
    warning(['System Identification Toolbox (arx) not found. Skipping model_psv_sdg call.\n' ...
             'Install the toolbox to evaluate directional coupling.']);
else
    [CSI2B, CVI2B, B2CSI, B2CVI, tH2B, tB2H] = model_psv_sdg( ...
        EEG_comp, RR, t_RR, CSI_series, CVI_series, Fs, time_eeg, wind);
end

%% 5) Basic plots for visual inspection
figure('Name','Synthetic RR and CSI/CVI','Color','w');
subplot(3,1,1); plot(t_RR, RR, '.-'); xlabel('Time (s)'); ylabel('RR (s)'); title('Inter-beat Intervals'); grid on;
subplot(3,1,2); plot(t_CSI_CVI, CSI_series); xlabel('Time (s)'); ylabel('CSI'); title('Time-varying CSI'); grid on;
subplot(3,1,3); plot(t_CSI_CVI, CVI_series); xlabel('Time (s)'); ylabel('CVI'); title('Time-varying CVI'); grid on;

figure('Name','Synthetic EEG Channels','Color','w');
plot(time_eeg, EEG_comp'); xlabel('Time (s)'); ylabel('Power (a.u.)'); title('Synthetic EEG Band-power Channels'); grid on;
legend(arrayfun(@(c) sprintf('Ch%d',c), 1:nCh, 'UniformOutput',false));

if exist('CSI2B','var')
    figure('Name','Estimated Couplings','Color','w');
    subplot(2,2,1); plot(tH2B, CSI2B(1,1:numel(tH2B))); xlabel('Time (s)'); ylabel('Coeff'); title('Heart→Brain CSI (Ch1)'); grid on;
    subplot(2,2,2); plot(tH2B, CVI2B(2,1:numel(tH2B))); xlabel('Time (s)'); ylabel('Coeff'); title('Heart→Brain CVI (Ch2)'); grid on;
    subplot(2,2,3); plot(tB2H, B2CSI(1,1:numel(tB2H))); xlabel('Time (s)'); ylabel('Index'); title('Brain→Heart CSI (Ch1)'); grid on;
    subplot(2,2,4); plot(tB2H, B2CVI(2,1:numel(tB2H))); xlabel('Time (s)'); ylabel('Index'); title('Brain→Heart CVI (Ch2)'); grid on;
end

%% 6) Console summary
fprintf('\nSummary:\n');
fprintf('  RR intervals: %d\n', numel(RR));
fprintf('  CSI/CVI vector length: %d (%.1f s span)\n', numel(CSI_series), t_CSI_CVI(end)-t_CSI_CVI(1));
fprintf('  EEG samples: %d (channels=%d)\n', Nt, nCh);
if exist('CSI2B','var')
    fprintf('  Coupling arrays size (Heart→Brain CSI2B): %s\n', mat2str(size(CSI2B)));
else
    fprintf('  Coupling not computed (missing ARX).\n');
end

% End of script
