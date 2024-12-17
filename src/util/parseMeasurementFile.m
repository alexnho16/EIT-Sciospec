function [measurementDataMultipleFrequencies, measurementParams] = parseMeasurementFile(measurementPath, useRealValues)
    % parseMeasurementFile parses measurement data files and averages the data.
    %
    % Parameters:
    %   measurementPath (string): The path to the folder containing measurement files.
    %   useRealValues (logical): Flag to determine whether to use real values.
    %
    % Returns:
    %   measurementDataMultipleFrequencies (struct): Parsed and averaged measurement data.
    %   measurementParams (struct): Parameters of the measurements, including filenames.

    files = sortAndGroupFiles(measurementPath);
    measurementData = struct();
    measurementParams = struct();
    measurementNames = {}; % Initialize measurement names
    
    for groupIndex = fieldnames(files)'
        groupName = groupIndex{1};
        fileGroup = files.(groupName);
        [dataAccumulator, params] = parseAndAccumulateData(fileGroup, useRealValues);
        
        if isempty(fieldnames(measurementParams))
            measurementParams = params;
        end
        
        % Add the group name to the measurement names
        measurementNames{end+1} = groupName;
        
        averagedData = averageData(dataAccumulator);
        measurementData.(groupName) = averagedData;
    end
    
    % Add measurement names to the params structure
    measurementParams.MeasurementNames = measurementNames;
    
    measurementDataMultipleFrequencies = measurementData;
end

function groupedFiles = sortAndGroupFiles(measurementPath)
    % sortAndGroupFiles sorts and groups measurement files based on their names.
    %
    % Parameters:
    %   measurementPath (string): The path to the folder containing measurement files.
    %
    % Returns:
    %   groupedFiles (struct): Grouped measurement files.

    fileList = dir(fullfile(measurementPath, '*.txt'));
    files = fileList(~[fileList.isdir]);
    numericValues = regexp({files.name}, '(\d+)', 'tokens');
    numericValues = cellfun(@(x) str2double(char(x{1})), numericValues);
    [~, sortedIndex] = sort(numericValues);
    files = files(sortedIndex);

    groupedFiles = struct();
    for fileIdx = 1:length(files)
        fileName = files(fileIdx).name;
        baseName = regexp(fileName, '\w+_\d+', 'match');
        if ~isempty(baseName)
            baseName = baseName{1};
            if ~isfield(groupedFiles, baseName)
                groupedFiles.(baseName) = {};
            end
            groupedFiles.(baseName){end+1} = fullfile(files(fileIdx).folder, fileName);
        end
    end
end

function [dataAccumulator, params] = parseAndAccumulateData(fileGroup, useRealValues)
    % parseAndAccumulateData parses and accumulates data from a group of files.
    %
    % Parameters:
    %   fileGroup (cell array): Group of file paths to be parsed.
    %   useRealValues (logical): Flag to determine whether to use real values.
    %
    % Returns:
    %   dataAccumulator (struct): Accumulated data matrices.
    %   params (struct): Measurement parameters.

    dataAccumulator = struct();
    frequencyKeys = {};
    params = struct();
    
    for i = 1:length(fileGroup)
        [voltagesGroundMatrix, measurementCurrent, measurementFrequencies, ...
            measurementChannels, inputChannels, outputChannels, patternType, isLogScale] = ...
            Data.parseMeasurementDataWithHeader(fileGroup{i}, useRealValues);
        
        if isempty(fieldnames(params))
            params.MeasurementCurrent = measurementCurrent;
            params.MeasurementFrequencies = measurementFrequencies;
            params.MeasurementChannels = measurementChannels;
            params.InputChannels = inputChannels;
            params.OutputChannels = outputChannels;
            params.PatternType = patternType;
            params.IsLogScale = isLogScale;
        end
        
        if isempty(frequencyKeys)
            frequencyKeys = fieldnames(voltagesGroundMatrix);
            for freqIdx = 1:length(frequencyKeys)
                dataAccumulator.(frequencyKeys{freqIdx}) = [];
            end
        end

        for freqIdx = 1:length(frequencyKeys)
            frequencyKey = frequencyKeys{freqIdx};
            dataAccumulator.(frequencyKey)(:,:,end + 1) = voltagesGroundMatrix.(frequencyKey);
        end
    end
end

function averagedData = averageData(dataAccumulator)
    % averageData averages the accumulated data matrices.
    %
    % Parameters:
    %   dataAccumulator (struct): Accumulated data matrices.
    %
    % Returns:
    %   averagedData (struct): Averaged data matrices.

    averagedData = struct();
    frequencyKeys = fieldnames(dataAccumulator);
    for freqIdx = 1:length(frequencyKeys)
        frequencyKey = frequencyKeys{freqIdx};
        if isempty(dataAccumulator.(frequencyKey))
            averagedData.(frequencyKey) = [];
        else
            averagedData.(frequencyKey) = mean(dataAccumulator.(frequencyKey), 3);
        end
    end
end
