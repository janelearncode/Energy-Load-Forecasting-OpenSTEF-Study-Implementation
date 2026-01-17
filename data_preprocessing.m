%% Clear workspace
clear; clc;

%% Define folder with CSVs
folder = fullfile('data','raw','iso_ne_hourly_load');
files = dir(fullfile(folder,'*.csv')); % get all CSV files

%% Create results folder
if ~exist(fullfile('results','plots'),'dir')
    mkdir(fullfile('results','plots'));
end

%% Preallocate cell array because when I put allData into the loop,
% variable appears to change size on every loop iteration. 
tables = cell(1, length(files));

%% Load all CSVs into cell array
for k = 1:length(files)
    filename = fullfile(folder, files(k).name);
    opts = detectImportOptions(filename);
    T = readtable(filename, opts);
    
    tables{k} = T;  % store each table into 'tables' array for k tables
end

%% Combine all tables at once
allData = vertcat(tables{:});
disp('All CSVs combined into one table');
disp(allData.Properties.VariableNames);

%% Create datetime from Date + HourEnding
% Convert Date to datetime if needed
if ~isdatetime(allData.Date)
    allData.Date = datetime(allData.Date);
end

% HourEnding is 1–24 → convert to hour 0–23
allData.Time = allData.Date + hours(allData.HourEnding - 1);

%sort by time
allData=sortrows(allData, 'Time');


%% PLOT (with peak)
figure
plot(allData.Time, allData.TotalLoad)

% add peak to the plot
hold on % Keep the current plot, and add anything next on top of it
[maxLoad, idx] = max(allData.TotalLoad);
peakTime = allData.Time(idx);

plot(peakTime, maxLoad, 'ro', 'MarkerFaceColor','r')
text(peakTime, maxLoad, sprintf(' Peak: %.0f MW', maxLoad))

xlabel('Time')
ylabel('Load (MW)')
title('ISO-NE Hourly Load with Peak')
grid on

%% TEST BASIC STATS
% Show min,max,mean:
minLoad=min(allData.TotalLoad);
maxLoad=max(allData.TotalLoad);
meanLoad=mean(allData.TotalLoad);

fprintf('Min Load: %.1f (MW)\n', minLoad');
fprintf('Max Load: %.1f (MW)\n', maxLoad');
fprintf('Mean Load: %.1f (MW)\n', meanLoad);


%% Daily Average Load
allData.Day = dateshift(allData.Time,'start','day');

% Create daily load, groupsummary func. to creates a table of summary statistics (like mean, sum, count) 
% by grouping data from an input table or array based on one or more grouping variables
dailyLoad = groupsummary(allData, 'Day', @(x) mean(x,'omitnan'), 'TotalLoad');

%give function mean_TotalLoad = AvgLoad
dailyLoad.Properties.VariableNames{end} = 'AvgLoad';

% PLOT
good = ~isnat(dailyLoad.Day) & ~isnan(dailyLoad.AvgLoad); % ensures we only plot valid points

figure
plot(dailyLoad.Day(good), dailyLoad.AvgLoad(good), '-o');
grid on
xlabel('Date');
ylabel('Average Load (MW)');
title('Daily Average ISO-NE Load');

% forces MATLAB to zoom in data (no "empty-looking" plot)
xlim([min(dailyLoad.Day(good)) max(dailyLoad.Day(good))])
ylim([min(dailyLoad.AvgLoad(good)) max(dailyLoad.AvgLoad(good))])

drawnow; %force MATLAB to reply immediately

%% DAILY AVERAGE & DAILY PEAK
dailyStats = groupsummary(allData,'Day',{'mean','max'}, 'TotalLoad');

figure('Visible','on')
plot(dailyStats.Day, dailyStats.mean_TotalLoad, 'LineWidth', 1.2)
hold on
plot(dailyStats.Day, dailyStats.max_TotalLoad, 'LineWidth', 1.2)
grid on
xlabel('Date')
ylabel('Load (MW)')
title('ISO-NE Daily Average vs Daily Peak Load')
legend('Daily Average','Daily Peak','Location','best')
drawnow

saveas(gcf, fullfile('results','plots','daily_avg_vs_peak.png'));

% Print peak daily load
[peakMW, idx] = max(dailyStats.max_TotalLoad);
peakDay = dailyStats.Day(idx);
fprintf('Peak daily load: %.0f MW on %s\n', peakMW, datetime(peakDay));


%% Quick overall summary
fprintf('Tell me about my dataset:\n');
fprintf('Date range: %s to %s\n', datetime(min(allData.Time)), datetime(max(allData.Time)));
fprintf('Overall mean load: %.0f MW\n', mean(allData.TotalLoad,'omitnan'));
fprintf('Overall min load: %.0f MW\n', min(allData.TotalLoad));
fprintf('Overall max load: %.0f MW\n', max(allData.TotalLoad));

%% TEST
size(dailyLoad);
head(dailyLoad);
