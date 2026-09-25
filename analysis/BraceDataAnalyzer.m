% compares a dribbling trial with the brace on vs off using the csvs from the pico logger
% filters the signals, finds the dribble impacts and wrist snaps, then compares the stats
clear; clc; close all;

% trial 1 was recorded with the brace on, trial 2 without it
here         = fileparts(mfilename('fullpath'));
brace_file   = fullfile(here, '..', 'data', 'trial_01.csv');
nobrace_file = fullfile(here, '..', 'data', 'trial_02.csv');

B  = readmatrix(brace_file);
NB = readmatrix(nobrace_file);

% columns are timestamp_ms, ax, ay, az, gx, gy, gz. time gets shifted to start at 0 and put in seconds
t_B  = (B(:,1) - B(1,1)) / 1000;
ax_B = B(:,2); ay_B = B(:,3); az_B = B(:,4);
gx_B = B(:,5); gy_B = B(:,6); gz_B = B(:,7);

t_NB  = (NB(:,1) - NB(1,1)) / 1000;
ax_NB = NB(:,2); ay_NB = NB(:,3); az_NB = NB(:,4);
gx_NB = NB(:,5); gy_NB = NB(:,6); gz_NB = NB(:,7);

% work out the real sample rate from the timestamps, should come out around 100 Hz
fs_B  = round(1 / median(diff(t_B)));
fs_NB = round(1 / median(diff(t_NB)));

fprintf('Brace:    %d samples, ~%d Hz\n', length(t_B),  fs_B);
fprintf('No brace: %d samples, ~%d Hz\n', length(t_NB), fs_NB);

% raw plots first just to see if the data looks right
figure;
subplot(3,1,1); plot(t_B, ax_B); ylabel('ax (m/s^2)'); title('Brace - Raw Accel'); grid on;
subplot(3,1,2); plot(t_B, ay_B); ylabel('ay (m/s^2)'); grid on;
subplot(3,1,3); plot(t_B, az_B); ylabel('az (m/s^2)'); xlabel('Time (s)'); grid on;

figure;
subplot(3,1,1); plot(t_B, gx_B); ylabel('gx (deg/s)'); title('Brace - Raw Gyro'); grid on;
subplot(3,1,2); plot(t_B, gy_B); ylabel('gy (deg/s)'); grid on;
subplot(3,1,3); plot(t_B, gz_B); ylabel('gz (deg/s)'); xlabel('Time (s)'); grid on;

% moving average over 10 samples (0.1s) to smooth out the noise
w = 10;

ax_Bf = movmean(ax_B,w); ay_Bf = movmean(ay_B,w); az_Bf = movmean(az_B,w);
gx_Bf = movmean(gx_B,w); gy_Bf = movmean(gy_B,w); gz_Bf = movmean(gz_B,w);

ax_NBf = movmean(ax_NB,w); ay_NBf = movmean(ay_NB,w); az_NBf = movmean(az_NB,w);
gx_NBf = movmean(gx_NB,w); gy_NBf = movmean(gy_NB,w); gz_NBf = movmean(gz_NB,w);

figure;
subplot(2,1,1);
plot(t_B, ax_B, 'Color',[.7 .7 .7]); hold on;
plot(t_B, ax_Bf, 'b', 'LineWidth',1.2);
ylabel('ax (m/s^2)'); title('Raw vs Filtered'); legend('Raw','Filtered'); grid on;
subplot(2,1,2);
plot(t_B, gx_B, 'Color',[.7 .7 .7]); hold on;
plot(t_B, gx_Bf, 'r', 'LineWidth',1.2);
ylabel('gx (deg/s)'); xlabel('Time (s)'); legend('Raw','Filtered'); grid on;

% magnitude combines all 3 axes so it doesnt matter how the sensor is rotated on the wrist
amag_B  = sqrt(ax_Bf.^2 + ay_Bf.^2 + az_Bf.^2);
gmag_B  = sqrt(gx_Bf.^2 + gy_Bf.^2 + gz_Bf.^2);
amag_NB = sqrt(ax_NBf.^2 + ay_NBf.^2 + az_NBf.^2);
gmag_NB = sqrt(gx_NBf.^2 + gy_NBf.^2 + gz_NBf.^2);

figure;
subplot(2,1,1);
plot(t_B, amag_B, 'b'); ylabel('|a| (m/s^2)'); title('Accel Magnitude (Brace)'); grid on;
subplot(2,1,2);
plot(t_B, gmag_B, 'r'); ylabel('|\omega| (deg/s)'); xlabel('Time (s)'); title('Gyro Magnitude (Brace)'); grid on;

% a peak only counts if its over the threshold, and peaks have to be 0.15s apart
% gravity alone is 9.81 so 15 m/s^2 means an actual impact, and the gap stops one bounce counting twice
a_thresh = 15;
g_thresh = 100;
min_dist = 0.15;

[pks_aB,  loc_aB]  = simple_findpeaks(amag_B,  a_thresh, round(min_dist*fs_B));
[pks_gB,  loc_gB]  = simple_findpeaks(gmag_B,  g_thresh, round(min_dist*fs_B));
[pks_aNB, loc_aNB] = simple_findpeaks(amag_NB, a_thresh, round(min_dist*fs_NB));
[pks_gNB, loc_gNB] = simple_findpeaks(gmag_NB, g_thresh, round(min_dist*fs_NB));

figure;
subplot(2,1,1);
plot(t_B, amag_B,'b'); hold on;
plot(t_B(loc_aB), pks_aB, 'rv','MarkerSize',8,'MarkerFaceColor','r');
ylabel('|a| (m/s^2)'); title('Accel Peaks (Brace)');
legend('Signal', sprintf('%d peaks',length(pks_aB))); grid on;
subplot(2,1,2);
plot(t_B, gmag_B,'r'); hold on;
plot(t_B(loc_gB), pks_gB, 'bv','MarkerSize',8,'MarkerFaceColor','b');
ylabel('|\omega| (deg/s)'); xlabel('Time (s)'); title('Gyro Peaks (Brace)');
legend('Signal', sprintf('%d peaks',length(pks_gB))); grid on;

figure;
subplot(2,1,1);
plot(t_NB, amag_NB,'b'); hold on;
plot(t_NB(loc_aNB), pks_aNB, 'rv','MarkerSize',8,'MarkerFaceColor','r');
ylabel('|a| (m/s^2)'); title('Accel Peaks (No Brace)');
legend('Signal', sprintf('%d peaks',length(pks_aNB))); grid on;
subplot(2,1,2);
plot(t_NB, gmag_NB,'r'); hold on;
plot(t_NB(loc_gNB), pks_gNB, 'bv','MarkerSize',8,'MarkerFaceColor','b');
ylabel('|\omega| (deg/s)'); xlabel('Time (s)'); title('Gyro Peaks (No Brace)');
legend('Signal', sprintf('%d peaks',length(pks_gNB))); grid on;

fB  = get_features(amag_B,  gmag_B,  t_B,  pks_aB,  loc_aB,  pks_gB,  loc_gB);
fNB = get_features(amag_NB, gmag_NB, t_NB, pks_aNB, loc_aNB, pks_gNB, loc_gNB);

names = {'Peak accel (m/s^2) - hardest single impact';
         'Mean accel (m/s^2) - average force over the trial';
         'Std accel (m/s^2) - how inconsistent the force is';
         'Peak gyro (deg/s) - fastest wrist rotation';
         'Mean gyro (deg/s) - average wrist rotation speed';
         'Std gyro (deg/s) - how inconsistent the rotation is';
         'Accel peak count - number of detected dribble impacts';
         'Gyro peak count - number of wrist snap events';
         'Avg time between accel peaks (s) - dribble tempo';
         'Avg time between gyro peaks (s) - wrist snap tempo'};

T = table(names, fB, fNB, 'VariableNames', {'Metric','Brace','NoBrace'});
fprintf('\n');
disp('Summary:');
disp(T);

fprintf('\n--- Results ---\n\n');

% percent change with the brace compared to without it
a_diff  = (fB(1) - fNB(1)) / fNB(1) * 100;
g_diff  = (fB(4) - fNB(4)) / fNB(4) * 100;
mg_diff = (fB(5) - fNB(5)) / fNB(5) * 100;

% anything under 10% is treated as basically the same since its only one trial each
if abs(a_diff) < 10
    fprintf('Peak accel is roughly the same between trials (%.1f%% diff).\n', a_diff);
    fprintf('  -> brace isnt reducing how hard the hand pushes.\n');
elseif a_diff > 0
    fprintf('Peak accel is %.1f%% higher with brace.\n', a_diff);
else
    fprintf('Peak accel is %.1f%% lower with brace.\n', abs(a_diff));
end

if g_diff < -10
    fprintf('Peak wrist rotation dropped %.1f%% with brace.\n', abs(g_diff));
    fprintf('  -> brace is limiting wrist snap, this is good.\n');
elseif g_diff > 10
    fprintf('Peak rotation went up %.1f%% with brace. check sensor mounting.\n', g_diff);
else
    fprintf('Wrist rotation didnt change much (%.1f%% diff).\n', abs(g_diff));
end

fprintf('Average rotational speed changed %.1f%% with brace.\n', mg_diff);

if ~isnan(fB(9)) && ~isnan(fNB(9))
    fprintf('Dribble tempo: %.3fs apart (brace) vs %.3fs (no brace).\n', fB(9), fNB(9));
    if fB(3) < fNB(3)
        fprintf('Accel std is lower with brace (%.1f vs %.1f) so motion is more consistent.\n', fB(3), fNB(3));
    else
        fprintf('Accel std is higher with brace (%.1f vs %.1f) so motion is more variable.\n', fB(3), fNB(3));
    end
end

% the goal is less wrist rotation without taking away hand force
fprintf('\nTakeaway: ');
if g_diff < -10 && abs(a_diff) < 15
    fprintf('brace limits wrist rotation without reducing hand force. thats the goal.\n');
elseif g_diff < -10 && a_diff < -15
    fprintf('brace is restricting both rotation and force, might be too tight.\n');
elseif abs(g_diff) < 10 && abs(a_diff) < 10
    fprintf('not a big difference. probably need longer recordings or more trials.\n');
else
    fprintf('results are mixed, run more trials and see if the pattern holds.\n');
end

figure;
subplot(2,1,1);
plot(t_B, amag_B, 'b'); hold on;
plot(t_NB, amag_NB, 'r');
ylabel('|a| (m/s^2)'); title('Accel Magnitude Comparison');
legend('Brace','No Brace'); grid on;
subplot(2,1,2);
plot(t_B, gmag_B, 'b'); hold on;
plot(t_NB, gmag_NB, 'r');
ylabel('|\omega| (deg/s)'); xlabel('Time (s)'); title('Gyro Magnitude Comparison');
legend('Brace','No Brace'); grid on;

figure;
labels = {'Peak Accel','Mean Accel','Peak Gyro','Mean Gyro','Accel Peaks','Avg Peak Interval'};
bvals  = [fB(1)  fB(2)  fB(4)  fB(5)  fB(7)  fB(9)];
nbvals = [fNB(1) fNB(2) fNB(4) fNB(5) fNB(7) fNB(9)];
bar(categorical(labels,labels), [bvals; nbvals]');
legend('Brace','No Brace','Location','best');
ylabel('Value'); title('Feature Comparison'); grid on;

% all 10 stats for one trial, matches the order of names above
function f = get_features(amag, gmag, t, pks_a, loc_a, pks_g, loc_g)
    f = zeros(10,1);
    f(1) = max(amag);  f(2) = mean(amag);  f(3) = std(amag);
    f(4) = max(gmag);  f(5) = mean(gmag);  f(6) = std(gmag);
    f(7) = length(pks_a);
    f(8) = length(pks_g);
    if length(loc_a) >= 2, f(9)  = mean(diff(t(loc_a))); else, f(9)  = NaN; end
    if length(loc_g) >= 2, f(10) = mean(diff(t(loc_g))); else, f(10) = NaN; end
end

% my own peak finder instead of findpeaks so it doesnt need the signal processing toolbox
% a point is a peak if its higher than both neighbors, over the threshold, and far enough from the last one
function [pks, locs] = simple_findpeaks(sig, thresh, mindist)
    pks = []; locs = [];
    for i = 2:length(sig)-1
        if sig(i) > sig(i-1) && sig(i) > sig(i+1) && sig(i) >= thresh
            if isempty(locs) || (i - locs(end)) >= mindist
                pks(end+1)  = sig(i);
                locs(end+1) = i;
            end
        end
    end
    pks = pks(:); locs = locs(:);
end
