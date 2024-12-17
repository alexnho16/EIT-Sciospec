classdef EIT < handle
    properties(Access = public)
        useRealValues logical = false;
        useRawValues logical = false;

        % Device and Connection Configuration
        connectionHandler

        % Data Handling
        savePath {mustBeText} = 'Measurement';

        % Measurement Meta Data
        measurementNames = {"Default_0", "Default_1"};
        measurementCount {mustBeInteger, mustBeNonnegative}
        measurementDataMultipleFrequencies
    end

    methods
        %% Setup
        function obj = EIT()
        end

        function obj = setupScioSpecConnection(obj, serialPortName, baudRate)
            try
                obj.connectionHandler = ScioSpec(serialPortName, baudRate);
            catch ME
                switch ME.identifier
                    case 'MATLAB:serialport:openFailed'
                        fprintf('Failed to connect to %s at baud rate %d. Please check your device and port settings.\n', serialPortName, baudRate);
                    otherwise
                        fprintf('An unexpected error occurred during setup: %s\n', ME.message);
                end
                rethrow(ME);
            end
        end

        function obj = configureConnectionHandler(obj, burstCount, current, startFrequency, endFrequency, frequencyCount, ...
                useLogFrequencys, measurementPrecision, measurementChannels, patternType)
            if isempty(obj.connectionHandler)
                obj.setupScioSpecConnection();
            end
            obj.connectionHandler = obj.connectionHandler.configureSetup(burstCount, current, startFrequency, endFrequency, frequencyCount, ...
                useLogFrequencys, measurementPrecision, measurementChannels, patternType);
        end

        function obj = useReal(obj, boolean)
            obj.useRealValues = boolean;
        end

        function obj = useRaw(obj, boolean)
            obj.useRawValues = boolean;
        end

        function obj = setSavePath(obj, path)
            if ~exist(path, 'dir')
                mkdir(path);
            end
            obj.savePath = path;
        end

        function obj = startPatternedMeasurement(obj, baseFolder, measurementNames, averagingCount, timeBetweenMeasurements, name)
            obj.connectionHandler.sendEITSetup();
            obj.measurementCount = length(measurementNames);
            obj.measurementNames = measurementNames;
            measurementData = struct();
            baseFolderName = sprintf('%s/%s/%s_%s', baseFolder, obj.connectionHandler.patternType, name, datetime('now', 'Format', 'yyyy-MM-dd_HH-mm-ss'));
            mkdir(baseFolderName);

            for i = 1:obj.measurementCount
                filePath = sprintf('%s/%s', baseFolderName, obj.measurementNames{i});
                [elapsedTime, frequencyMatrices] = obj.averageMeasurement(averagingCount, filePath);
                frequencyFields = fieldnames(frequencyMatrices);

                if ~isfield(measurementData, measurementNames{i})
                    measurementData.(measurementNames{i}) = struct();
                end

                for freqIdx = 1:length(frequencyFields)
                    frequencyKey = frequencyFields{freqIdx};
                    measurementData.(measurementNames{i}).(frequencyKey) = frequencyMatrices.(frequencyKey);
                end

                pauseDuration = max(0, timeBetweenMeasurements - elapsedTime);
                if ~(i == obj.measurementCount)
                    pause(pauseDuration);
                end
            end

            obj.measurementDataMultipleFrequencies = measurementData;
        end

        function obj = startMultiplePatterns(obj, baseFolder, measurementNames, averagingCount, timeBetweenMeasurements, name)
            obj.measurementCount = length(measurementNames);
            obj.measurementNames = measurementNames;
            adjacentFolder = sprintf('%s/%s/%s_%s', baseFolder, "Adjacent", name, datetime('now', 'Format', 'yyyy-MM-dd_HH-mm-ss'));
            mkdir(adjacentFolder);
            diagonalFolder = sprintf('%s/%s/%s_%s', baseFolder, "Diagonal", name, datetime('now', 'Format', 'yyyy-MM-dd_HH-mm-ss'));
            mkdir(diagonalFolder);
            hybridFolder = sprintf('%s/%s/%s_%s', baseFolder, "Hybrid", name, datetime('now', 'Format', 'yyyy-MM-dd_HH-mm-ss'));
            mkdir(hybridFolder);
            oppositeFolder = sprintf('%s/%s/%s_%s', baseFolder, "Opposite", name, datetime('now', 'Format', 'yyyy-MM-dd_HH-mm-ss'));
            mkdir(oppositeFolder);
            for i = 1:obj.measurementCount
                obj.connectionHandler.patternType = "Adjacent";
                obj.connectionHandler = obj.connectionHandler.checkPatternString("Adjacent");
                filePath = sprintf('%s/%s', adjacentFolder, obj.measurementNames{i});
                obj.connectionHandler.sendEITSetup();
                [elapsedTime1, ~] = obj.averageMeasurement(averagingCount, filePath);

                obj.connectionHandler.patternType = "Diagonal";
                obj.connectionHandler = obj.connectionHandler.checkPatternString("Diagonal");
                filePath = sprintf('%s/%s', diagonalFolder, obj.measurementNames{i});
                obj.connectionHandler.sendEITSetup();
                [elapsedTime2, ~] = obj.averageMeasurement(averagingCount, filePath);

                obj.connectionHandler.patternType = "Opposite";
                obj.connectionHandler = obj.connectionHandler.checkPatternString("Opposite");
                filePath = sprintf('%s/%s', oppositeFolder, obj.measurementNames{i});
                obj.connectionHandler.sendEITSetup();
                [elapsedTime3, ~] = obj.averageMeasurement(averagingCount, filePath);

                obj.connectionHandler.patternType = "Hybrid";
                obj.connectionHandler = obj.connectionHandler.checkPatternString("Hybrid");
                filePath = sprintf('%s/%s', hybridFolder, obj.measurementNames{i});
                obj.connectionHandler.sendEITSetup();
                [elapsedTime4, ~] = obj.averageMeasurement(averagingCount, filePath);

                elapsedTime = elapsedTime4 + elapsedTime3 + elapsedTime2 + elapsedTime1;
                disp(elapsedTime)
                pauseDuration = max(0, timeBetweenMeasurements - elapsedTime);
                if ~(i == obj.measurementCount)
                    pause(pauseDuration);
                end
            end
        end

        function obj = analyzeMultiplePatternedMeasurements(obj, baseFolder, n, patternType, name, plotPath, showOnly)
            % Create a unique session folder
            counter = 0;
            sessionFolder = sprintf('%s/%s_%s', baseFolder, name, patternType);
            while exist(sessionFolder, 'dir')
                counter = counter + 1;
                sessionFolder = sprintf('%s/%s_%s_%d', baseFolder, name, patternType, counter);
            end

            mkdir(sessionFolder);
            allMeasurements = struct();

            obj.connectionHandler.sendEITSetup();

            for i = 1:n
                measurementName = sprintf('Measurement_%d.txt', i);
                [~, frequencyMatrices] = obj.startSingleMeasurement(sessionFolder, measurementName);

                freqKeys = fieldnames(frequencyMatrices);
                if i == 1
                    for fk = 1:length(freqKeys)
                        allMeasurements.(freqKeys{fk}) = [];
                    end
                end

                for fk = 1:length(freqKeys)
                    freqKey = freqKeys{fk};
                    allMeasurements.(freqKey) = cat(3, allMeasurements.(freqKey), frequencyMatrices.(freqKey));
                end
            end

            Stats.recomputeStatistics(sessionFolder, plotPath, showOnly, obj.useRealValues);
        end

        function [obj, frequencyMatrices] = startSingleMeasurement(obj, baseFolder, name)
            filePath = sprintf('%s/%s', baseFolder, name);
            [~, frequencyMatrices] = obj.singleMeasurement(filePath);
        end


        %% Helper Methods
        function [totalDuration, averagedData] = averageMeasurement(obj, averagingCount, basePath)
            totalDuration = 0;
            accumulatedMatrices = [];

            for i = 1:averagingCount
                currentSavePath = sprintf('%s-(%d).txt', basePath, i);

                [time, matrices] = obj.singleMeasurement(currentSavePath);
                totalDuration = totalDuration + time;

                if isempty(accumulatedMatrices)
                    accumulatedMatrices = matrices;
                else
                    frequencyFields = fieldnames(matrices);
                    for freqIdx = 1:length(frequencyFields)
                        freqKey = frequencyFields{freqIdx};
                        accumulatedMatrices.(freqKey) = accumulatedMatrices.(freqKey) + matrices.(freqKey);
                    end
                end
            end

            averagedData = accumulatedMatrices;
            frequencyFields = fieldnames(averagedData);
            for freqIdx = 1:length(frequencyFields)
                freqKey = frequencyFields{freqIdx};
                averagedData.(freqKey) = averagedData.(freqKey) / averagingCount;
            end
        end

        function [time, matrices] = singleMeasurement(obj, savePath)
            tic;
            data = obj.connectionHandler.startEITMeasurement();
            obj.connectionHandler.writeDataWithHeader(data, savePath);
            [matrices, ~, ~, ~, ~, ~, ~] = Data.parseMeasurementDataWithHeader(savePath, obj.useRealValues);
            time = toc;
        end

        function [voltagesGroundMatrix, measurementCurrent, measurementFrequencies, ...
                measurementChannels, inputChannels, outputChannels, patternType, isLogScale] = continousMeasurement(obj, savePath)
            data = obj.connectionHandler.startEITMeasurement();
            obj.connectionHandler.writeDataWithHeader(data, savePath);
            [voltagesGroundMatrix, measurementCurrent, measurementFrequencies, ...
                measurementChannels, inputChannels, outputChannels, patternType, isLogScale] = Data.parseMeasurementDataWithHeader(savePath, obj.useRealValues);
        end
    end
end
