# Time‑domain Poincaré model for CSI/CVI

This document disentangles the mathematics implemented in `original_code/compute_CSI_CVI.m` to build time‑varying indices inspired by sympathetic and vagal activity (CSI/CVI) from inter‑beat intervals (IBI, i.e., RR intervals).

The code computes:

- Global Poincaré descriptors SD1 and SD2 from the entire RR sequence
- Time‑varying SD1(t) and SD2(t) on sliding windows
- Re‑centers SD1(t)/SD2(t) to the global baseline
- Produces CSI(t), CVI(t) (scaled) and resamples them on a uniform grid

We use KaTeX for the equations.

## Notation

- Let the non‑interpolated RR (IBI) sequence be $\{r_n\}_{n=1}^N$ measured at timestamps $\{\tau_n\}_{n=1}^N$ (in seconds).
- Define first differences $\Delta r_n = r_{n+1} - r_n$ for $n=1,\dots,N-1$.
- For any finite set $X = \{x_i\}$, let $\operatorname{Var}(X)$ denote the sample variance and $\operatorname{mean}(X)$ the sample mean.
- The Poincaré plot is the point cloud $\{(r_n, r_{n+1})\}$; SD1 and SD2 are its standard deviations along the transverse and longitudinal axes, respectively.

## 1) Global Poincaré descriptors

From the full RR sequence:

$$
\mathrm{SD1}_{\mathrm{glob}} = \sqrt{\tfrac{1}{2} \operatorname{Var}(\Delta r)}
$$

$$
\mathrm{SD2}_{\mathrm{glob}} = \sqrt{\,2\,\operatorname{Var}(r) - \tfrac{1}{2}\,\operatorname{Var}(\Delta r)\,}
$$

These match the standard Poincaré relationships between SD1, SD2, and the variance of RR and its first difference.

## 2) Sliding window SD1(t), SD2(t)

Fix a window length `wind` (in seconds). Windows are anchored at RR timestamps and end at time $t_k$ equal to one of the $\tau_i$:

- For each window end time $t_k = \tau_{i_k}$, define the window index set
  $$
  \mathcal{W}(t_k) = \{\, n \mid t_k - \texttt{wind} \le \tau_n \le t_k \,\}
  $$
- Extract RR values $\{r_n\}_{n\in\mathcal{W}(t_k)}$ and their first differences $\{\Delta r_n\}_{n\in\mathcal{W}(t_k)}$.
- Compute time‑varying Poincaré descriptors:

$$
\mathrm{SD1}(t_k) = \sqrt{\tfrac{1}{2}\,\operatorname{Var}\big(\{\Delta r_n\}_{n\in\mathcal{W}(t_k)}\big)}
$$

$$
\mathrm{SD2}(t_k) = \sqrt{\,2\,\operatorname{Var}\big(\{r_n\}_{n\in\mathcal{W}(t_k)}\big) - \tfrac{1}{2}\,\operatorname{Var}\big(\{\Delta r_n\}_{n\in\mathcal{W}(t_k)}\big)\,}
$$

The code collects the sequence of window end times in a vector $t_C = [\,t_1, t_2, \dots \,]$.

## 3) Re‑centering to the global baseline

Let $\overline{\mathrm{SD1}}$ and $\overline{\mathrm{SD2}}$ be the sample means across all windows. The implementation recenters the time‑varying series to the global SD1/SD2 baselines:

$$
\widetilde{\mathrm{SD1}}(t_k) = \mathrm{SD1}(t_k) - \overline{\mathrm{SD1}} + \mathrm{SD1}_{\mathrm{glob}}
$$

$$
\widetilde{\mathrm{SD2}}(t_k) = \mathrm{SD2}(t_k) - \overline{\mathrm{SD2}} + \mathrm{SD2}_{\mathrm{glob}}
$$

This preserves the temporal fluctuations while matching the global (whole‑record) Poincaré scale.

## 4) CSI and CVI definitions (implemented vs classic)

Two variants are relevant:

- Implemented (numeric stability scaling used by the downstream ARX model):

$$
\mathrm{CVI}(t_k) = 10\,\widetilde{\mathrm{SD1}}(t_k), \qquad
\mathrm{CSI}(t_k) = 10\,\widetilde{\mathrm{SD2}}(t_k)
$$

- Classic (often found in literature; left commented in the code):

$$
\mathrm{CVI}_{\mathrm{classic}}(t_k) = 100\,\widetilde{\mathrm{SD1}}(t_k)\,\widetilde{\mathrm{SD2}}(t_k), \qquad
\mathrm{CSI}_{\mathrm{classic}}(t_k) = \frac{\widetilde{\mathrm{SD2}}(t_k)}{\widetilde{\mathrm{SD1}}(t_k)}
$$

The chosen scaling (multiplying by constants 10 or 100) is a magnitude normalization choice that eases model convergence in later identification steps. It does not change the relative temporal pattern.

## 5) Uniform resampling (output time grid)

The outputs are interpolated to a uniform time grid at sampling frequency $F_s = 4\,\text{Hz}$ with step $\Delta t = 1/F_s$:

- Define
  $$
  t_{\text{out}} = [\, t_C(1),\ t_C(1)+\Delta t,\ t_C(1)+2\Delta t,\ \dots,\ t_C(\text{end})\,]
  $$
- Interpolate with cubic splines (1‑D) to obtain uniform‑time series:

$$
\mathrm{CVI}_{\text{out}}(t) = \operatorname{SplineInterpolate}\big(\{(t_k,\ \mathrm{CVI}(t_k))\},\ t\big)
$$

$$
\mathrm{CSI}_{\text{out}}(t) = \operatorname{SplineInterpolate}\big(\{(t_k,\ \mathrm{CSI}(t_k))\},\ t\big)
$$

The interpolation is only evaluated within the convex hull of $t_C$ to avoid extrapolation artifacts at the edges.

## 6) Algorithm summary (as in the code)

1. Set $F_s = 4$ Hz and build a dense time vector for reference.
2. Compute $\mathrm{SD1}_{\mathrm{glob}}$ and $\mathrm{SD2}_{\mathrm{glob}}$ from the full RR using the formulas above.
3. Slide a window of length `wind` seconds, anchored at successive RR timestamps $t_k$, and compute $\mathrm{SD1}(t_k)$ and $\mathrm{SD2}(t_k)$.
4. Recenter: $\widetilde{\mathrm{SD1}}(t_k)$, $\widetilde{\mathrm{SD2}}(t_k)$ using the global baselines.
5. Build indices (implemented version): $\mathrm{CVI}(t_k)=10\,\widetilde{\mathrm{SD1}}(t_k)$ and $\mathrm{CSI}(t_k)=10\,\widetilde{\mathrm{SD2}}(t_k)$.
6. Interpolate $\mathrm{CVI}(t_k)$ and $\mathrm{CSI}(t_k)$ onto a uniform grid $t_{\text{out}}$ using cubic splines to obtain $\mathrm{CVI}_{\text{out}}(t)$ and $\mathrm{CSI}_{\text{out}}(t)$.

## 7) Poincaré geometry (visual intuition)

A Poincaré plot displays points $(r_n, r_{n+1})$. SD1 and SD2 correspond to the standard deviation along the axes obtained by a $45^\circ$ rotation:

- Along the identity line ("long axis"), proportional to long‑term variability.
- Perpendicular to the identity line ("short axis"), proportional to short‑term variability.

Define the $45^\circ$ rotated coordinates

$$
\begin{aligned}
y_{\perp,n} &= \tfrac{1}{\sqrt{2}}(r_{n+1} - r_n),\\
y_{\parallel,n} &= \tfrac{1}{\sqrt{2}}(r_{n+1} + r_n).
\end{aligned}
$$

Then

$$
\mathrm{SD1} = \operatorname{std}(y_{\perp}), \qquad \mathrm{SD2} = \operatorname{std}(y_{\parallel}).
$$

ASCII schematic (not to scale):

```text
      r_{n+1}
        ^
        |           ·  ·
        |        ·         ·       SD2 (along y = x)
        |     ·      ○      ·
        |        ·         ·       ○ ellipse: major ≈ 2·SD2, minor ≈ 2·SD1
        |           ·  ·            center near (mean r, mean r)
        |-----------------------> r_n
                  \
                   \
                    \  SD1 (perpendicular to y = x)
```

### Optional: Quick Poincaré plot with SD1/SD2 ellipse (MATLAB)

```matlab
function plot_poincare_with_ellipse(RR)
    % RR: vector of interbeat intervals (seconds)
    r1 = RR(1:end-1);
    r2 = RR(2:end);
    % SD1/SD2 from classic rotated coordinates
    yperp = (r2 - r1)/sqrt(2);
    ypar  = (r2 + r1)/sqrt(2);
    SD1 = std(yperp);
    SD2 = std(ypar);
    mu = [mean(RR) mean(RR)];

    % Build ellipse oriented at 45 degrees
    t = linspace(0, 2*pi, 200);
    E = [SD2*cos(t); SD1*sin(t)];         % axes lengths (major=SD2, minor=SD1)
    R = [cos(pi/4) -sin(pi/4); sin(pi/4) cos(pi/4)];
    Erot = (R*E)';
    Erot = Erot + mu;                     % center near (mean r, mean r)

    figure; hold on; box on; axis equal;
    scatter(r1, r2, 8, 'filled', 'MarkerFaceAlpha', 0.25);
    plot([min(RR) max(RR)], [min(RR) max(RR)], 'k--', 'LineWidth', 1); % y = x
    plot(Erot(:,1), Erot(:,2), 'r', 'LineWidth', 1.5);
    xlabel('r_n (s)'); ylabel('r_{n+1} (s)');
    legend('Points', 'y = x', sprintf('Ellipse (SD2=%.3f, SD1=%.3f)', SD2, SD1), ...
           'Location','best');
    title('Poincaré plot with SD1/SD2 ellipse');
end
```

## Remarks

- Windows end at RR timestamps (not centered). If you require centered windows, shift the window definition accordingly.
- Using first differences $\Delta r$ inside each window mirrors the geometry of the Poincaré plot (points $(r_n, r_{n+1})$), where SD1 relates to short‑term variability and SD2 to long‑term variability.
- The re‑centering step removes drift in the windowed estimates and restores the global scale, improving comparability across recordings.
