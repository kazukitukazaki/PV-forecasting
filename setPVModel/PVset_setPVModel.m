% ---------------------------------------------------------------------------
% PV prediction: Model development algorithm 
% 2019/02/18 Updated gyeong gak
% kakkyoung2@gmail.com
% ----------------------------------------------------------------------------
function flag = PVset_setPVModel(LongTermPastData)
    tic;    
    %% Get file path
    path = fileparts(LongTermPastData);     
    %% parameters
    ValidDays = 30; % it must be above 1 day. 3days might provide the best performance
    n_valid_data = 96*ValidDays; % 24*4*day

    %% Load data
    if strcmp(LongTermPastData, 'NULL') == 0    % if the filename is not null
        longPast = csvread(LongTermPastData,1,0); 
    else  % if the fine name is null
        flag = -1; 
        return
    end
    %% Devide the data into training and validation
    valid_data = longPast(end-n_valid_data+1:end, :); 
    train_data = longPast(1:end-n_valid_data, :); 
    valid_predictors = longPast(end-n_valid_data+1:end, 1:end-1); 
    
    %% Train each model using past load data
    % Note: 0 means not true. If this function got the past data, model have to be trained
    op_flag = 1; % 1: training mode
    shortPast = longPast(end-7*96+1:end, :); 
    PVset_PV_LSTM(op_flag, longPast, shortPast, path);
    PVset_PV_kmeans(op_flag, longPast, shortPast, path);
    PVset_PV_fitnet_ANN(op_flag, longPast, shortPast, path);
    %% Validate the performance of each model
    op_flag = 2; % 2: forecasting mode      
    for day = 1:ValidDays 
        TimeIndex = size(train_data,1)+1+96*(day-1);  % Indicator of the time instance for validation data in past_load, 
        short_past_load = longPast(TimeIndex-96*7:TimeIndex-1, 1:end); % size of short_past_load is always "672*11" for one week data set 
        valid_predictor = valid_predictors(1+(day-1)*96:day*96, 1:end);  % predictor for 1 day (96 data instances) 
       y_ValidEstIndv(1).data(:,day) = PVset_PV_kmeans(op_flag, valid_predictor, short_past_load, path);
       y_ValidEstIndv(2).data(:,day) = PVset_PV_fitnet_ANN(op_flag, valid_predictor, short_past_load, path);
       y_ValidEstIndv(3).data(:,day) = PVset_PV_LSTM(op_flag, valid_predictor, short_past_load, path);
    end
    %% Optimize the coefficients for the additive model
    coeff = PVset_pso_main(y_ValidEstIndv, valid_data(:,end));  
    
    %% Generate probability interval using validation result
   for hour = 1:24
        for i = 1:size(coeff(1).data,1)
            if i == 1
                y_est(1+(hour-1)*4:hour*4,:) = coeff(hour).data(i).*y_ValidEstIndv(i).data(1+(hour-1)*4:hour*4,:);
            else
                y_est(1+(hour-1)*4:hour*4,:) = y_est(1+(hour-1)*4:hour*4,:) + coeff(hour).data(i).*y_ValidEstIndv(i).data(1+(hour-1)*4:hour*4,:);  
            end
        end
    end    
    
    % Restructure
    for day = 1:ValidDays        
        y_ValidEstComb(1+(day-1)*96:day*96, 1) = y_est(:, day);
    end
    
    
    % error from validation data[%] error[%], hours, Quaters
    err = [y_ValidEstComb - valid_data(:, end) valid_predictors(:,5) valid_predictors(:,6)];  %5:�ð�,6:����
    % Initialize the structure for error distribution
    % structure of err_distribution.data is as below:
    % row=25hours(0~24 in "LongTermPastData"), columns=4quarters.
    % For instance, "err_distribution(1,1).data" means 0am 0(first) quarter, which contains array like [e1,e2,e3....] 
    for hour = 1:25
        for quarter = 1:4
            err_distribution(hour,quarter).data(1) = NaN;            
        end
    end
    % build the error distibution
    for k = 1:size(err,1)
        if isnan(err_distribution(err(k,2)+1, err(k,3)+1).data(1)) == 1 
            err_distribution(err(k,2)+1, err(k,3)+1).data(1) = err(k,1);
        else
            err_distribution(err(k,2)+1, err(k,3)+1).data(end+1) = err(k,1);
        end
    end 
    
    %% Save .mat files
    s1 = 'PV_pso_coeff_';
    s2 = 'PV_err_distribution_';
    s3 = num2str(longPast(1,1)); % Get building index
    name(1).string = strcat(s1,s3);
    name(2).string = strcat(s2,s3);
    varX(1).value = 'coeff';
    varX(2).value = 'err_distribution';
    extention='.mat';
    for i = 1:size(varX,2)
        matname = fullfile(path, [name(i).string extention]);
        save(matname, varX(i).value);
    end 
    
%     % for debugging --------------------------------------------------------
%         for day = 1:ValidDays       
%             y_EstIndv(1).data(1+(day-1)*96:day*96,1) =  y_ValidEstIndv(1).data(:,day);
%         end
%         true = valid_data(:, end);
%         % true = nan(size(y_mean,1), 1);
%         TrainGraph(1:size(y_ValidEstComb,1), y_ValidEstComb, true, [], 'Combined for forecast data'); % Combined
%         TrainGraph(1:size(y_ValidEstComb,1), y_EstIndv(1).data, true, [], 'k-means for forecast data'); % k-means 
%     % for debugging --------------------------------------------------------------------- 
    
    flag = 1;    
    toc;
end