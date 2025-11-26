function [CSI2B, CVI2B, B2CSI, B2CVI, tH2B, tB2H] = model_psv_sdg(EEG_comp, IBI, t_IBI, CSI, CVI, Fs, time, wind)
% MODEL_PSV_SDG
% Estimates directional brain–heart couplings using an SDG (Synthetic Data
% Generation) scheme:
%   - Heart→Brain: ARX model of EEG band‑power with CSI/CVI as exogenous input
%   - Brain→Heart: normalized averages of Cs/Cp (from a Poincaré‑based HRV model)
%
% Inputs
% - EEG_comp : matrix (channels × time) of EEG band‑power (aligned to 'time')
% - IBI      : NON‑interpolated inter‑beat intervals (seconds)
% - t_IBI    : timestamps (seconds) for each IBI sample
% - CSI, CVI : time‑aligned indices (scaled)
% - Fs       : sampling rate (Hz) of EEG_comp/time
% - time     : time vector (seconds) for EEG_comp
% - wind     : window length in seconds for the model (e.g., 15)
%
% Outputs
% - CSI2B, CVI2B : Heart→Brain ARX coefficients over time (per channel)
% - B2CSI, B2CVI : Brain→Heart normalized indices over time (per channel)
% - tH2B, tB2H   : time axes for the two coupling directions

% Author: Diego Candia-Rivera (diego.candia.r@ug.uchile.cl)

%% Basic shape check

% If data were provided as 1 × T instead of T × 1, flip.
[Nch,Nt] = size(EEG_comp);
if Nt==1
    EEG_comp = EEG_comp';
    [Nch,Nt] = size(EEG_comp);
end

%% HRV sub‑model (Cs, Cp) from Poincaré formulation
% Use nominal LF/HF center frequencies to construct a simple dynamical model
% of sympatho‑vagal components, computed over sliding windows along 'time'.
f_lf = 0.1;
f_hf = 0.25;

w_lf = 2*pi*f_lf;
w_hf = 2*pi*f_hf;

ss = wind*Fs;         % window length in samples on the 1 Hz time base
sc = 1;               % stride (samples) between consecutive windows
nt = ceil((length(time)-ss)/sc); % number of windows

Cs = zeros(1,nt);
Cp = zeros(1,nt);
TM = zeros(1,nt);


for i = 1:nt
    ix1 = (i-1)*sc + 1;
    ix2 = ix1 + ss - 1;
    ixm = floor(mean(ix1:ix2));   
%   Alternative: align to end of window → ixm = ix2
    t1 = time(ix1);
    t2 = time(ix2);
    ix = find(t_IBI >= t1 & t_IBI<= t2);

    
    mu_ibi = mean(IBI(ix));     % local mean IBI (s)
    mu_hr  = 1 / mu_ibi;        % local mean HR (Hz)
    
    G = sin(w_hf/(2*mu_hr))-sin(w_lf/(2*mu_hr)); 
    
    M_11 = sin(w_hf/(2*mu_hr))*w_lf*mu_hr/(sin(w_lf/(2*mu_hr))*4);
    M_12 = -sqrt(2)*w_lf*mu_hr/(8*sin(w_lf/(2*mu_hr)));
    M_21 = -sin(w_lf/(2*mu_hr))*w_hf*mu_hr/(sin(w_hf/(2*mu_hr))*4);
    M_22 = sqrt(2)*w_hf*mu_hr/(8*sin(w_hf/(2*mu_hr)));
    M = [M_11, M_12; M_21, M_22];          % mixing matrix
    L = max(IBI(ix)) - min(IBI(ix));        % range of IBI (long-term var)
    W = sqrt(2) * max(abs(IBI(ix(2:end)) - IBI(ix(1:end-1)))); % short-term
    C = 1/G * M * [L; W];                   % Cs (symp), Cp (vagal)
    Cs(i) = C(1);   Cp(i) = C(2);
    TM(i) = time(ixm);
end


%% Interpolate and align series on a common time axis (avoid extrapolating)
t1 = max([time(1) TM(1)]);
t2 = min([time(end) TM(end)]);
time2 = time(time >=t1 & time <=t2);

Cs = interp1(TM, Cs , time2, 'spline');
Cp = interp1(TM, Cp , time2, 'spline');

CSI = interp1(time, CSI , time2, 'spline');
CVI = interp1(time, CVI , time2, 'spline');

% Interpolate EEG power to the same time base
EEG_old = EEG_comp;
[Nch, Nt] = size(EEG_old);
clear EEG_comp

for i = 1 : Nch
    EEG_comp(i,:) = interp1(time, EEG_old(i,:), time2, 'spline');
end

time = time2; % adopt the aligned time vector

% Optional preprocessing: user‑defined artifact cleaning (no‑op by default)
EEG_comp = clean_artif(EEG_comp);
% EEG_comp = sqrt(EEG_comp);
% Cs = Cs / std(Cs);
% Cp = Cp / std(Cp);

%% Heart→Brain and Brain→Heart estimation per channel
% Heart→Brain: ARX coefficient (B(2)) over sliding windows.
% Brain→Heart: running averages of Cs/Cp normalized by local EEG power.

parfor ch = 1:Nch % Optional: can replace by 'for' if Parallel Toolbox is unavailable
    [CSI2B(ch,:), CVI2B(ch,:), B2CSI(ch,:), B2CVI(ch,:)] = SDG(EEG_comp(ch,:), CSI, CVI, Cs, Cp, wind*Fs);
end

%% Time vectors for coupling series
% Index heart→brain at the beginning of each window; brain→heart excludes
% the initial 'wind' seconds to ensure complete windows.
tH2B = time(1 : end-wind*Fs);
tB2H = time(wind*Fs+1 : end-wind*Fs);

% in the middle of the window
% tH2B = time(floor(wind/2) +1 : end-ceil(wind/2));
% tB2H = time(wind+1 : end-wind) + wind/2;

end

function [CSI_to_EEG, CVI_to_EEG, EEG_to_CSI, EEG_to_CVI] = SDG(EEG_ch, HRV_CSI, HRV_CVI, Cs_i, Cp_i, window)

    Nt = length(EEG_ch);
    % First window handled explicitly to initialize outputs
    for i = 1 : window
        arx_data = iddata(EEG_ch(i:i+window)', HRV_CSI(i:i+window)',1); 
        model_eegP = arx(arx_data,[1 1 1]);                                                 
        CSI_to_EEG(i) = model_eegP.B(2);

        arx_data = iddata(EEG_ch(i:i+window)', HRV_CVI(i:i+window)',1); 
        model_eegP = arx(arx_data,[1 1 1]);                                                 
        CVI_to_EEG(i) = model_eegP.B(2);
        
        pow_eeg(1,i) = mean(EEG_ch(i:i+window));  % local mean band power                                 
    end
    
    
    for i = window+1:min([length(Cp_i),Nt-window, length(HRV_CSI)-window])

    %% Heart→Brain estimation (ARX coefficient B(2))
        arx_data = iddata(EEG_ch(i:i+window)', HRV_CSI(i:i+window)',1); 
        model_eegP = arx(arx_data,[1 1 1]); 
        CSI_to_EEG(i) = model_eegP.B(2); 

        arx_data = iddata(EEG_ch(i:i+window)', HRV_CVI(i:i+window)',1); 
        model_eegP = arx(arx_data,[1 1 1]); 
        CVI_to_EEG(i) = model_eegP.B(2); 
        
        pow_eeg(1,i) = mean(EEG_ch(i:i+window));

        %% Brain→Heart estimation (normalized by EEG power)
        if i-window <= length(Cp_i)-window-1
            EEG_to_CVI(i-window) = mean((Cp_i(i-window:i))./pow_eeg(i-window:i));
            EEG_to_CSI(i-window) = mean((Cs_i(i-window:i))./pow_eeg(i-window:i));
        else
            EEG_to_CVI(i-window) = EEG_to_CVI(i-window-1);
            EEG_to_CSI(i-window) = EEG_to_CSI(i-window-1);
        end
    end

end