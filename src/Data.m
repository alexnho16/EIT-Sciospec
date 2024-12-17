classdef Data
    methods (Static)
        function [voltagesGroundMatrix, measurementCurrent, measurementFrequencies, ...
                measurementChannels, inputChannels, outputChannels, patternType, isLogScale] = ...
                parseMeasurementDataWithHeader(filePath, useRealValues)
            % parseMeasurementDataWithHeader parses a measurement data file with header.

            fileId = fopen(filePath, 'r');
            if fileId == -1
                error('Failed to open file.');
            end

            headerLine = strtrim(fgetl(fileId));
            [measurementCurrent, measurementFrequencies, measurementChannels, ...
                isLogScale, patternType] = Data.parseHeader(headerLine);

            voltageValues = struct();
            inChannels = [];
            outChannels = [];

            while ~feof(fileId)
                line = upper(strtrim(fgetl(fileId)));
                if isempty(line)
                    continue;
                end

                hexNumbers = regexp(line, '[0-9A-F]{2}', 'match');
                [startChannel, endChannel, frequencyIndex] = Data.parseChannelInfo(hexNumbers);
                frequency = measurementFrequencies(frequencyIndex + 1);

                frequencyKey = sprintf('Freq%d', round(frequency));
                injectionKey = sprintf('Ch%dto%d', startChannel, endChannel);

                voltageValues = Data.updateVoltageStruct(voltageValues, frequencyKey, injectionKey, hexNumbers);

                inChannels(end + 1) = startChannel;
                outChannels(end + 1) = endChannel;
            end

            fclose(fileId);

            [inputChannels, outputChannels] = Data.setUniqueChannels(inChannels, outChannels);

            voltagesGround = voltageValues;
            voltagesGroundMatrix = Data.calculateAllFrequencyMatrices(voltagesGround, measurementFrequencies, useRealValues);
        end

        function [measurementCurrent, measurementFrequencies, measurementChannels, isLogScale, patternType] = ...
                parseHeader(headerLine)
            % parseHeader extracts information from the header line.

            patterns = {
                'Current: ([\d.]+)',
                'Start Frequency: ([\d.]+)',
                'End Frequency: ([\d.]+)',
                'Frequencycount: (\d+)',
                'Channels: (\d+)',
                'Log = (\w+)',
                'Patterntype = (\w+)'
                };

            matches = cellfun(@(p) regexp(headerLine, p, 'tokens'), patterns, 'UniformOutput', false);

            measurementCurrent = str2double(matches{1}{1}{1});
            startFrequency = str2double(matches{2}{1}{1});
            endFrequency = str2double(matches{3}{1}{1});
            frequencyCount = str2double(matches{4}{1}{1});
            measurementChannels = str2double(matches{5}{1}{1});
            isLogScale = strcmpi(matches{6}{1}{1}, 'true');
            if isempty(matches{7})
                patternType = 'default';
            else
                patternType = matches{7}{1}{1};
            end

            if frequencyCount == 1
                measurementFrequencies = startFrequency;
            elseif isLogScale
                measurementFrequencies = round(logspace(log10(startFrequency), log10(endFrequency), frequencyCount));
            else
                measurementFrequencies = linspace(startFrequency, endFrequency, frequencyCount);
            end
        end

        function [startChannel, endChannel, frequencyIndex] = parseChannelInfo(hexNumbers)
            % parseChannelInfo parses channel information from hex numbers.

            startChannel = hex2dec(hexNumbers{2});
            endChannel = hex2dec(hexNumbers{3});
            frequencyIndex = hex2dec(strjoin(hexNumbers(4:5), ''));
        end

        function voltageValues = updateVoltageStruct(voltageValues, frequencyKey, injectionKey, hexNumbers)
            % updateVoltageStruct updates the voltage structure with new data.

            if ~isfield(voltageValues, frequencyKey)
                voltageValues.(frequencyKey) = struct();
            end
            if ~isfield(voltageValues.(frequencyKey), injectionKey)
                voltageValues.(frequencyKey).(injectionKey) = struct();
            end

            channelID = 1;
            for i = 10:8:length(hexNumbers) - 1
                realHex = strjoin(hexNumbers(i:i + 3), '');
                imagHex = strjoin(hexNumbers(i + 4:i + 7), '');
                realValue = typecast(uint32(hex2dec(realHex)), 'single');
                imagValue = typecast(uint32(hex2dec(imagHex)), 'single');
                voltageValues.(frequencyKey).(injectionKey).(sprintf('Ch%d', channelID)) = complex(realValue, imagValue);
                channelID = channelID + 1;
            end
        end

        function [inputChannels, outputChannels] = setUniqueChannels(inChannels, outChannels)
            % setUniqueChannels sets unique input and output channels.

            channelPairs = [inChannels; outChannels]';
            [uniqueChannelPairs, ~, ~] = unique(channelPairs, 'rows', 'stable');
            inputChannels = uniqueChannelPairs(:, 1)';
            outputChannels = uniqueChannelPairs(:, 2)';
        end

        function voltageMatrices = calculateAllFrequencyMatrices(voltagesGround, measurementFrequencies, useRealValues)
            % calculateAllFrequencyMatrices computes matrices for all frequencies.

            voltageMatrices = struct();
            for i = 1:length(measurementFrequencies)
                frequency = measurementFrequencies(i);
                frequencyKey = sprintf('Freq%d', round(frequency));

                if isfield(voltagesGround, frequencyKey)
                    matrix = Data.getVoltageMatrixForFrequency(voltagesGround, measurementFrequencies, i, useRealValues);
                    voltageMatrices.(frequencyKey) = matrix;
                else
                    warning('Frequency %d Hz not found in the measurement data.', frequency);
                end
            end
        end

        function matrix = getVoltageMatrixForFrequency(voltagesGround, measurementFrequencies, frequencyIndex, useRealValues)
            % getVoltageMatrixForFrequency extracts the voltage matrix for a specific frequency.

            frequency = measurementFrequencies(frequencyIndex);
            frequencyKey = sprintf('Freq%d', round(frequency));

            if isfield(voltagesGround, frequencyKey)
                injectionData = voltagesGround.(frequencyKey);
                injectionFields = fieldnames(injectionData);
                matrix = [];

                for i = 1:length(injectionFields)
                    injectionKey = injectionFields{i};
                    channelData = injectionData.(injectionKey);
                    channelFields = fieldnames(channelData);
                    tempRow = arrayfun(@(k) real(channelData.(channelFields{k})) * useRealValues + ...
                        channelData.(channelFields{k}) * ~useRealValues, 1:length(channelFields));

                    matrix = [matrix; tempRow];
                end
            else
                warning('Specified frequency not found in the measurement data.');
                matrix = [];
            end
        end

        function adjacentMatrix = convertToAdjacentMatrix(groundMatrix)
            % convertToAdjacentMatrix converts a ground matrix to an adjacent matrix.

            [numRows, numCols] = size(groundMatrix);
            adjacentMatrix = zeros(numRows, numCols);

            for i = 1:numRows
                for j = 1:numCols
                    nextIdx = mod(j, numCols) + 1;
                    adjacentMatrix(i, j) = -(groundMatrix(i, nextIdx)- groundMatrix(i, j));
                end
            end
        end

        function adjacentMatrices = convertToAdjacentMatrixForFirstFrequency(matrix)
            frequencyKeys = fieldnames(matrix);
            adjacentMatrices = struct();
            for j = 1:length(frequencyKeys)
                freqKey = frequencyKeys{j};
                groundMatrix = matrix.(freqKey);
                adjacentMatrices.freqKey = Data.convertToAdjacentMatrix(groundMatrix);
            end
        end

        function oppositeMatrix = convertToOppositeMatrix(groundMatrix)
            % convertToOppositeMatrix converts a ground matrix to an opposite matrix.

            [numRows, numCols] = size(groundMatrix);
            oppositeMatrix = zeros(numRows, numCols);
            halfNumCols = floor(numCols / 2);

            for i = 1:numRows
                for j = 1:numCols
                    oppositeIdx = mod(j + halfNumCols - 1, numCols) + 1;
                    oppositeMatrix(i, j) = groundMatrix(i, oppositeIdx) - groundMatrix(i, j);
                end
            end
        end

        function convertedStruct = convertAllToAdjacent(measurementsStruct)
            % Converts all matrices in the measurementsStruct to adjacent matrices.
            %
            % Parameters:
            %   measurementsStruct (struct): The struct containing the measurementIndex
            %                                 with nested frequencyMatrices.
            %
            % Returns:
            %   convertedStruct (struct): The struct with all frequency matrices converted to adjacent matrices.

            convertedStruct = struct();
            measurementIndexes = fieldnames(measurementsStruct);

            for i = 1:length(measurementIndexes)
                measurementIndex = measurementIndexes{i};
                frequencyStruct = measurementsStruct.(measurementIndex);
                frequencyKeys = fieldnames(frequencyStruct);

                for j = 1:length(frequencyKeys)
                    freqKey = frequencyKeys{j};
                    groundMatrix = frequencyStruct.(freqKey);
                    convertedStruct.(measurementIndex).(freqKey) = Data.convertToAdjacentMatrix(groundMatrix);
                end
            end
        end

        function convertedStruct = convertAllToOpposite(measurementsStruct)
            % Converts all matrices in the measurementsStruct to opposite matrices.
            %
            % Parameters:
            %   measurementsStruct (struct): The struct containing the measurementIndex
            %                                 with nested frequencyMatrices.
            %
            % Returns:
            %   convertedStruct (struct): The struct with all frequency matrices converted to opposite matrices.

            convertedStruct = struct();
            measurementIndexes = fieldnames(measurementsStruct);

            for i = 1:length(measurementIndexes)
                measurementIndex = measurementIndexes{i};
                frequencyStruct = measurementsStruct.(measurementIndex);
                frequencyKeys = fieldnames(frequencyStruct);

                for j = 1:length(frequencyKeys)
                    freqKey = frequencyKeys{j};
                    groundMatrix = frequencyStruct.(freqKey);
                    convertedStruct.(measurementIndex).(freqKey) = Data.convertToOppositeMatrix(groundMatrix);
                end
            end
        end
    end
end
