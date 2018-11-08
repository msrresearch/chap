function output = tobii2matlab(full_tobii_name, output_folder_name, log, events2, vars2)
    
    if (~exist('log', 'var'))
        log = false;
    end
    if (~exist('events2', 'var'))
        events2 = [];
    end    
    if (~exist('vars2', 'var'))
        vars2 = [];
    end
    output = [];
    [path, file_name, ext] = fileparts(full_tobii_name);
    if ~strcmpi(ext, '.tbi')
        return;
    end;
      
    print_log(['Start load and convert TOBII file: ' strrep(file_name, '_', '\_') ext], log);

        
    print_log(['Start loading and convert tbi file: ' strrep(file_name, '_', '\_') ext], log);
    copyfile(full_tobii_name,[path filesep file_name '.dat']);
    
    
    raw_data_table  = readtable([path filesep file_name '.dat'], 'Delimiter', ',');
    data.timestamps = raw_data_table.RecordingTimestamp;
    
    
    raw_data_table.PupilDiameterLeft(raw_data_table.PupilDiameterLeft==0) = raw_data_table.PupilDiameterRight(raw_data_table.PupilDiameterLeft==0);
    raw_data_table.PupilDiameterRight(raw_data_table.PupilDiameterRight==0) = raw_data_table.PupilDiameterLeft(raw_data_table.PupilDiameterRight==0);
    
    data.pupil_size = (raw_data_table.PupilDiameterRight + raw_data_table.PupilDiameterLeft)/2;
    
    data.pupil_size(data.pupil_size<0) = 0;
    data.pupil_size(isnan(data.pupil_size)) = 0;

    data.pupil_x = data.pupil_size;
    data.pupil_y = data.pupil_size;
    print_log('Start loading pupil data', log);  
    
    timestamps = data.timestamps;
    data.rate = 0;
    first_index = 2;
    while data.rate==0
        first_index = first_index+1;
        data.rate   = roundn(1000/(timestamps(first_index) - timestamps(first_index-1)), 1);
    end;
 
    timestamps = timestamps/(1000/data.rate);
    
    
    data.file_name  = full_tobii_name;     

    %% Get all the indexes of user's messages
    
    tic;
    event_csv_name = [path filesep file_name '_events.csv'];
    if ~exist(event_csv_name, 'file')
        print_log(strcat('Error (3): events file does not found, please add: ', strrep(strcat(file_name, '_events.csv') ,'_','\_') , ' to ', path), log);    
        return;
    end;

%         

    try
        mes_data_table = readtable(event_csv_name, 'Delimiter', ',');    
    catch
        print_log('Error (4): incompetible file, please check your file', log);    
        return;
    end;
    event_msgs        = mes_data_table.Event;
    event_timestamps  = mes_data_table.RecordingTimestamp/(1000/data.rate);

%     event_msgs = raw_data_table.Event;
    trial_ids = find(~cellfun(@isempty, strfind(event_msgs,'TRIALID'))); %trial is defined by message with the form TRIALID [num_of_trial]
    if(isempty(trial_ids))
        print_log('Error: trials did not found', log);
        return;
    end;
    trial_data.trial_names     = cellfun(@(x) str2double(char(regexp(char(x),'\d+','match'))), event_msgs(trial_ids));        
    trial_data.Trial_Onset_num = arrayfun(@(timestamp) get_trial_data_start(timestamp, timestamps), event_timestamps(trial_ids));
    
    Trial_Offset_ids              = ~cellfun(@isempty, strfind(event_msgs, 'TRIAL_END')); %trial is defined by message with the form TRIALID [num_of_trial]
    trial_data.Trial_Offset_num   = arrayfun(@(x) get_trial_data_start(x, timestamps), event_timestamps(Trial_Offset_ids));
   
    trial_data.trial_length    = trial_data.Trial_Offset_num-trial_data.Trial_Onset_num;
    data.trial_data = struct2table(trial_data);

    print_log(['Finished loading messages: ' num2str(toc) ' seconds'], log);    

    %%  Get gase's information & timestamps
    tic;
    
    
    
    var_ids = find(~cellfun(@isempty, strfind(event_msgs,'!V TRIAL_VAR')));

    if ~isempty(var_ids)
        total_var_data = parse_data.parse_vars(event_msgs, event_timestamps, timestamps, var_ids, trial_data.Trial_Onset_num);
        data.total_var_data_table = struct2table(total_var_data);
    end

    vars_file = strcat(path, filesep, file_name, '_vars.csv');
    if exist(vars_file, 'file')
        try
            var_data_table = parse_data.parse_external_vars(vars_file);
            data.total_var_data_table = [data.total_var_data_table, var_data_table];
        catch err
            print_log(['Error: ' err.message], log);
            return;
        end
    end

    print_log('Parsing events', log);    
    data.event_data = [];
    event_ids = find(~cellfun(@isempty, strfind(event_msgs,'!E TRIAL_EVENT_VAR')));
        event_full_data = event_msgs(event_ids);
        event_full_timestamps = event_timestamps(event_ids);

    if ~isempty(event_ids)
        event_data_table = parse_data.parse_events(event_full_data, event_full_timestamps, timestamps, data.trial_data.Trial_Onset_num);
        data.total_var_data_table = [data.total_var_data_table, event_data_table];
    end;

    data.events2 = events2;
    data.vars2   = vars2;
    trial_data.trial_length = trial_data.Trial_Offset_num-trial_data.Trial_Onset_num;
    data.total_var_data_table.event_Trial_Offset = trial_data.trial_length;

    save([output_folder_name filesep file_name '.chp'], 'data');
    output = data;
end

function start_time = get_trial_data_start(timestamp, timestamps)
    start_time      = find(timestamp>timestamps, 1, 'last');
end

