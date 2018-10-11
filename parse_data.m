classdef parse_data
    methods(Static)
        function [var_data, var_data_table] = parse_external_vars(vars_file)
            var_data_table = readtable(vars_file, 'Delimiter', ',');    
            var_data = [];
%             var_names = fieldnames(var_data_table);
%             ext_vars = var_names(2:end-1);
%             
%             trials = var_data_table(:, 1);
%             var_data = [];
%             for var = 1:size(ext_vars, 1)
%                 var_name =  ext_vars{var};
%                 vals = var_data_table.(char(ext_vars(var)));
%                 for trial = 1:size(trials, 1)
%                     temp_var_data(trial, :).trial_id = trial;
%                     temp_var_data(trial, :).var_name = var_name;
%                     temp_var_data(trial, :).var_val  = vals{trial};
%                 end
%                 var_data = [var_data; temp_var_data];
%             end       
            
            var_data_table.trial_id = [];
        end
        
        
        
        function total_var_data = parse_vars(event_msgs, event_timestamps, timestamps, var_ids, Trial_Onset_num, external)
            if (~exist('external', 'var'))
                external = false;
            end
            var_full_data = event_msgs(var_ids);
            for var = 1:size(var_full_data, 1)
                timestamp = event_timestamps(var_ids(var));
                sample_id = find(timestamps<=timestamp, 1, 'last');
                trial_id  = find(Trial_Onset_num<sample_id, 1, 'last');
                var_data_arr  = strsplit(cell2mat(var_full_data(var)));
                if external
                    total_var_data.(char(var_data_arr(1)))(trial_id, :) = var_data_arr(2);
                else
                    total_var_data.(char(var_data_arr(3)))(trial_id, :) = strrep(var_data_arr(4), '''', '') ;
                end
            end
            var_names = fieldnames(total_var_data);
            max_values = size(Trial_Onset_num, 1);

            for var = 1:size(var_names, 1)
                if size(total_var_data.(char(var_names(var))), 1) < max_values
                    total_var_data.(char(var_names(var))){max_values, :} = [];
                end
            end
            
        end
        
        function event_data_table = parse_events(event_msgs, event_timestamps, timestamps, Trial_Onset_num, Trial_Offset_num, external)
            if (~exist('external', 'var'))
                external = false;
            end

            for event=1:size(event_msgs, 1)
                timestamp  = event_timestamps(event);
                sample_id  = find(timestamps>=timestamp, 1, 'first');
                trial_id   = find(Trial_Onset_num<=sample_id, 1, 'last'); 

                event_str  = char(event_msgs(event));
                if(external)
                    event_data = strsplit(event_str);
                    event_name  = ['event_' char(event_data(2:end))];
                else
                    event_data = strsplit(event_str);
                    event_name = ['event_' char(event_data(3))];
                end
                if(isempty(trial_id))
                    event_parsed_data.trial_id   = -1;
                    event_parsed_data.event_val  = -1;
                    continue;
                end
                if external && length(event_data) == 2 && str2double(event_data{1})>0
                    event_diff_val = (timestamps(Trial_Offset_num(trial_id))-timestamps(Trial_Onset_num(trial_id))-str2double(event_data{1}));
                else
                    event_diff_val = (timestamp-timestamps(Trial_Onset_num(trial_id)));
                end
                total_event_data.(char(event_name))(trial_id, :) = event_diff_val;    
            end
            event_names = fieldnames(total_event_data);
            max_values = size(Trial_Onset_num, 1);
            for event = 1:size(event_names, 1)
                if size(total_event_data.(char(event_names(event))), 1) < max_values
                    total_event_data.(char(event_names(event)))(max_values, :) = 0;
                end
            end

            event_data_table = struct2table(total_event_data);
        end
        
    end
end