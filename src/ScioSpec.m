classdef ScioSpec
    properties(Access=public)
        SerialObject
        isConnected logical = false
        burstCount double {mustBeNonnegative, mustBeInteger}
        amplitudeCurrent double {mustBeNonnegative, mustBeInRange(amplitudeCurrent, 10e-6, 10e-3)}
        startFrequency double {mustBeNonnegative, mustBeNumeric}
        endFrequency double {mustBeNonnegative, mustBeNumeric}
        frequencyCount double {mustBeNonnegative, mustBeInteger}
        useLogFrequencys logical
        measurementPrecision double {mustBeNonnegative, mustBeInRange(measurementPrecision, 1, 5)}
        measurementChannels double {mustBeNonnegative, mustBeInteger}
        inputChannels
        outputChannels
        foundData
        patternType
    end

    properties (Constant)
        DefaultCOMPort = 'COM3'
        DefaultBaudRate = 9600
    end

    methods
        function obj = ScioSpec(serialPortName, baudRate)
            if nargin > 0
                obj.SerialObject = serialport(serialPortName, baudRate);
                obj.isConnected = true;
            end
        end

        function obj = configureSetup(obj, burstCount, amplitudeCurrent, startFrequency, endFrequency, frequencyCount, useLogFrequencys, measurementPrecision, measurementChannels, patternType)
            obj.burstCount = burstCount;
            obj.amplitudeCurrent = amplitudeCurrent;
            obj.startFrequency = startFrequency;
            obj.endFrequency = endFrequency;
            obj.frequencyCount = frequencyCount;
            obj.useLogFrequencys = useLogFrequencys;
            obj.measurementPrecision = measurementPrecision;
            obj.measurementChannels = measurementChannels;
            obj.patternType = patternType;
            obj = obj.checkPatternString(patternType);
        end


      function obj = checkPatternString(obj, pattern)
            switch pattern
                case "Adjacent"
                    obj = obj.setAdjacentPattern();
                case "Diagonal"
                    obj = obj.setDiagonalPattern();
                case "Montgomery"
                    obj = obj.setMontgomeryPattern();
                case "Opposite"
                    obj = obj.setOppositePattern();
                case "Hybrid"
                    obj = obj.setHybridPattern();
                otherwise
                    error('Unknown pattern type.');
            end
        end
        

        function obj = setDiagonalPattern(obj)
            obj.inputChannels =  [2,  3,  4,   5,  6,  7, 8, 14, 15, 16, 1, 2, 3, 4];
            obj.outputChannels = [16, 15, 14, 13, 12, 11,10, 12, 11, 10, 9, 8, 7, 6];
        end


        function obj = setDiagonalPatternLeichtBau(obj)
            obj.inputChannels =  [1,  1,  2,  3,  4,  5,  6,  7,  8, 9];
            obj.outputChannels = [5, 13, 12, 11, 10,  9, 16, 15, 14, 13];
        end

        
        function obj = setHybridPattern(obj)
             obj.inputChannels = [2,  3,  4,   5,  6,  7, 8, 14, 15, 16, 1, 2, 3, 4, 1, 2, 3, 4,5,5, 6, 7, 8, 9];
            obj.outputChannels = [16, 15, 14, 13, 12, 11,10, 12, 11, 10, 9, 8, 7, 6, 13,12,11,10,9,1,16,15,14,13];
        end

        function obj = setAdjacentPattern(obj)
            obj.inputChannels =  [2,3,4,5,6,7,8,9,10,11,12,13,14,15,16, 1];
            obj.outputChannels = [1,2,3,4,5,6,7,8, 9,10,11,12,13,14,15,16];
        end
        
        function obj = setMontgomeryPattern(obj)
            obj.inputChannels =  [1,1];
            obj.outputChannels = [5,13];
        end

        function obj = setOppositePattern(obj)
            obj.inputChannels =  [ 1, 2, 3, 4,5,5, 6, 7, 8, 9];
            obj.outputChannels = [13,12,11,10,9,1,16,15,14,13];
        end

        function obj = setCustomPattern(obj, inputChannels, outputChannels)
            if length(inputChannels) ~= length(outputChannels)
                error('Input channels and output channels must have the same length.');
            end
            obj.inputChannels = inputChannels;
            obj.outputChannels = outputChannels;
        end

        function data = setupAndStartEITMeasurement(obj)
            obj.sendEITSetup()
            data = obj.startEITMeasurement();
        end

        function sendEITSetup(obj)
            obj.sendSetup();
            obj.sendEITExitation();
        end

        function data = startEITMeasurement(obj)
            count = length(obj.inputChannels) * obj.frequencyCount * obj.burstCount;
            data = obj.startMeasurement(count);
            obj.endMeasurement();
        end

        function obj = close(obj)
            disp("Close serialport")
            % Close the serial port connection
            if obj.isConnected && ~isempty(obj.SerialObject) && isvalid(obj.SerialObject)
                delete(obj.SerialObject);
                obj.SerialObject = [];
                obj.isConnected = false;
            end
        end

        function resetDevice(obj)
            % Reset Sciospec
            if obj.isConnected
                resetSystemFrame = [0xA1, 0, 0xA1]; 
                obj.sendSciospecCommand(resetSystemFrame);
            else
                warning('Serial port not connected. Cannot reset device.');
            end
        end

        function activateTimestamp(obj, activate)
            % Activate or deactivate the timestamp
            if obj.isConnected
                enable = 0;
                if activate
                    enable = 1;
                end
                activateTimestamp = [0x97, 2, 1, enable, 0x97];
                obj.sendSciospecCommand(activateTimestamp);
            else
                warning('Serial port not connected. Cannot activate timestamp.');
            end
        end

        function getTimestamp(obj)
            % Get Timestamp status
            if obj.isConnected
                getTimestamp = [0x98, 0x01, 0x01, 0x98];
                obj.sendSciospecCommand(getTimestamp);
            else
                warning('Serial port not connected. Cannot get timestamp.');
            end
        end

        function clearFEStack(obj)
            % Clear stack 
            if obj.isConnected
                clearStack = [0xB0, 3, 0xFF, 0xFF, 0xFF, 0xB0];
                disp("Clear Stack")
                obj.sendSciospecCommand(clearStack);
            else
                warning('Serial port not connected. Cannot clear stack.');
            end
        end
        
        function setFE(obj, mode, channel, range)
            % 1 for twoPoint, 2 for fourPoint, 3 for threePoint
            supportedModes = [1, 2, 3]; 
            % 1 for BNCPort, 2 for extensionPort, 3 for extensionPort2
            supportedChannels = [1, 2, 3]; 
            % 1 for cur10ma, 2 for cur100ua, 4 for cur1ua, 6 for cur10na
            supportedRanges = [1, 2, 4, 6];
            
            % Check if the provided parameters are supported
            if ismember(mode, supportedModes) && ismember(channel, supportedChannels) && ismember(range, supportedRanges) 
                commandFrame = [0xB0, 3, mode, channel, range, 0xB0];
                disp("Set Frontend")
                obj.sendSciospecCommand(commandFrame);
            else
                % One or more parameters are not supported
                warning('One or more provided parameters are not supported.');
            end
        end

        function getFE(obj)
            if obj.isConnected
                getFECommand = [0xB1, 0, 0xB1];
                response = obj.sendSciospecCommand(getFECommand);
                response = str2double(cellstr(response));

                % Definitions for mapping numbers to strings
                measurementMode = ["Two Point", "Four Point", "Three Point"]; 
                measurementChannel = ["BNC Port", "Extension Port", "Internal MUX"];
                measurementRange = ["10mA","100µA","","1µA","","100nA"];

                % Extract relevant parts of the response
                modeIndex = response(3);
                channelIndex1 = response(4);
                channelIndex2 = response(5);

                mode = measurementMode(modeIndex);
                channel1 = measurementChannel(channelIndex1);
                channel2 = measurementRange(channelIndex2);

                % Display the results
                disp(['Mode: ', mode]);
                disp(['Channel 1: ', channel1]);
                disp(['Channel 2: ', channel2]);
            else
                warning('Serial port not connected. Cannot get FE.');
            end
        end
        
        function getExtensionPortChannel(obj)
            if obj.isConnected
                getExtensionportChannel = [0xB3, 0, 0xB3];
                disp("Extensionportchannel")
                obj.sendSciospecCommand(getExtensionportChannel);
            else
                warning('Serial port not connected. Cannot get extension port channel.');
            end
        end

        function getExtensionModule(obj)
            if obj.isConnected
                getExtensionPort = [0xB5, 0, 0xB5];
                disp("Extensionmodule")
                obj.sendSciospecCommand(getExtensionPort);
            else
                warning('Serial port not connected. Cannot get extension module.');
            end
        end

        function setSetup(obj, startFrequency, stopFrequency, count, useLog, precision, amplitude)
            if obj.isConnected
                startFrequency = obj.toSingleFloat(startFrequency); %4
                stopFrequency = obj.toSingleFloat(stopFrequency); %4
                count = obj.toSingleFloat(count); %4
                log = 0; %1
                precision = obj.toSingleFloat(precision); %4
                amplitude = obj.toSingleFloat(amplitude); %4

                phaseSynch = [2, obj.convertToBinary4(0)]; %enable phase synch %5
                current = [3, 0, 0, 0, 0x02]; % use current as excitation %5
                pointDelay = [1, obj.convertToBinary4(1000)]; %5
                if useLog
                    log = 1;
                end

                frequencyList = [0xB6, 37, 3, startFrequency, stopFrequency, count, log, precision, amplitude, pointDelay, phaseSynch, current, 0xB6];
                disp("Frequency")
                obj.sendSciospecCommand(frequencyList);

                amplitudeList = [0xB6, 6, 5, 2, amplitude, 0xB6];
                disp("Amplitude")
                obj.sendSciospecCommand(amplitudeList);
            else
                warning('Serial port not connected. Cannot set setup.');
            end
        end

        function sendSetup(obj)
            if obj.isConnected
                % Set Default first
                defaultSetup = [0xC4, 1, 1, 0xC4];
                disp("Default EIT")
                obj.sendSciospecCommand(defaultSetup);

                % Set Default second time (Sciospec does it too)
                defaultSetup = [0xC4, 1, 1, 0xC4];
                disp("Default EIT")
                obj.sendSciospecCommand(defaultSetup);

                % Set burstcount
                burstCountSP = obj.convertToBinary2(obj.burstCount);
                burstSetup = [0xC4, 3, 2, burstCountSP, 0xC4];
                disp("Count EIT")
                obj.sendSciospecCommand(burstSetup);

                % Set Amplitude
                amplitudeSP = obj.toSingleFloat(obj.amplitudeCurrent);
                amplitudeSetup = [0xC4, 5, 5, amplitudeSP, 0xC4];
                disp("Amplitude EIT")
                obj.sendSciospecCommand(amplitudeSetup);

                % Set Precision
                precisionSP = obj.toSingleFloat(obj.measurementPrecision);
                precisionSetup = [0xC4, 5, 3, precisionSP, 0xC4];
                disp("Precision EIT")
                obj.sendSciospecCommand(precisionSetup);

                % Channels
                channels = 1:obj.measurementChannels;
                channelSetup = [0xC4, length(channels) + 1, 8, channels, 0xC4];
                disp("channels EIT")
                obj.sendSciospecCommand(channelSetup);

                % Set Frequency
                startFrequencySP = obj.toSingleFloat(obj.startFrequency);
                stopFrequencySP = obj.toSingleFloat(obj.endFrequency);
                frequencyCountSP = obj.convertToBinary2(obj.frequencyCount);
                log = 0;
                if obj.useLogFrequencys
                    log = 1;
                end
                frequencySetup = [0xC4, 12, 4, startFrequencySP, stopFrequencySP, frequencyCountSP, log, 0xC4];
                disp("Frequency EIT")
                obj.sendSciospecCommand(frequencySetup);
            else
                warning('Serial port not connected. Cannot send setup.');
            end
        end

        function obj = configureEITExcitation(obj, inputChannel, outputChannel)
            obj.inputChannels = inputChannel;
            obj.outputChannels = outputChannel;
        end

        function sendEITExitation(obj)
            if obj.isConnected
                for i = 1:1:length(obj.inputChannels)
                    curInChannel = obj.inputChannels(i);
                    curOutChannel = obj.outputChannels(i);
                    excitation = [0xC4, 3, 6, curInChannel, curOutChannel, 0xC4];
                    fprintf('Excitation: In %d, Out %d \n', curInChannel, curOutChannel);
                    obj.sendSciospecCommand(excitation);
                end
            else
                warning('Serial port not connected. Cannot send EIT excitation.');
            end
        end
        
        function data = startMeasurement(obj, count)
            if obj.isConnected
                startList = [0xB8, 1, 2, 0xB8];
                disp("Start Measurement")
                obj.sendSciospecCommand(startList);
                data = obj.processMeasurementData(count);
            else
                warning('Serial port not connected. Cannot start measurement.');
                data = [];
            end
        end

        function endMeasurement(obj)
            if obj.isConnected
                stopList = [0xB8, 1, 0, 0xB8];
                disp("Stop Measurement")
                obj.sendSciospecCommand(stopList);
            else
                warning('Serial port not connected. Cannot end measurement.');
            end
        end

        function setDefaultSetup(obj)
            if obj.isConnected
                % Set default setup
                emptySetupFrame = [0xB6, 1, 1, 0xB6];
                disp("Default Setup")
                obj.sendSciospecCommand(emptySetupFrame);
            else
                warning('Serial port not connected. Cannot set default setup.');
            end
        end
        
        function saveToSlot(obj, slotNumber)
            if obj.isConnected
                savetoSlot = [0xB6, 2, 0x20, slotNumber, 0xB6];
                fprintf('Save to %d Slot\n', slotNumber);
                disp(savetoSlot)
                obj.sendSciospecCommand(savetoSlot);
            else
                warning('Serial port not connected. Cannot save to slot.');
            end
        end
        
        function data = sendSciospecCommand(obj, commandFrame)
            if ~obj.isConnected
                warning('Serial port not connected. Command not sent.');
                data = [];
                return;
            end

            try
                write(obj.SerialObject, commandFrame, "uint8");
            catch ex
                warning(ex.identifier, 'msg', ex.message)
                obj.close()
                data = [];
                return;
            end
            response = [];

            % Loop until the acknowledge frame is read
            while true
                byte = read(obj.SerialObject, 1, "uint8");
                response = [response, byte]; % Append the next byte

                % Match the last 4 bytes for the acknowledge frame
                if length(response) >= 4 && response(end-3) == 24 && response(end) == 24
                    % Check frame
                    ackCode = response(end-1);
                    ScioSpec.interpretAckCode(ackCode);
                    break; % Exit loop when acknowledge frame is found
                end
            end

            if length(response) > 4
                disp(dec2hex(response(1:end-4)));
            end
            disp("-----------------------------------------------------------")
            data = dec2hex(response(1:end-4));
        end

        function data = readSerialPortForTime(obj, duration)
            if ~obj.isConnected
                warning('Serial port not connected. Cannot read serial port.');
                data = [];
                return;
            end

            data = [];
            startTime = tic;
            
            % read the serial port data for the set duration
            while toc(startTime) < duration
                if obj.SerialObject.NumBytesAvailable > 0
                    newData = read(obj.SerialObject, obj.SerialObject.NumBytesAvailable, "uint8");
                    data = [data, newData];
                else
                    pause(0.01);
                end
            end
            
            % convert to hex
            hexData = dec2hex(data);
            disp('Data as Hex:');
            disp(hexData);
        end

        function foundData = processMeasurementData(obj, expectedMeasurements)
            if ~obj.isConnected
                warning('Serial port not connected. Cannot process measurement data.');
                foundData = [];
                return;
            end

            measurementCount = 0;
            dataBuffer = uint8([]);
            timeout = 10;
            startTime = tic;
            processedData = uint8([]);

            while measurementCount < expectedMeasurements
                % Check for new data, and store them in the buffer
                if obj.SerialObject.NumBytesAvailable > 0
                    newData = read(obj.SerialObject, obj.SerialObject.NumBytesAvailable, "uint8");
                    newData = uint8(newData);
                    try
                        dataBuffer = [dataBuffer, newData];
                    catch ME
                        disp(['Error processing data: ', ME.message]);
                    end
                    % Find the start of the data, marked by 'b8'
                    while true
                        startIndex = find(dataBuffer == hex2dec('b8'), 1, 'first');
                        if isempty(startIndex)
                            break;
                        end
                        
                        if length(dataBuffer) >= (startIndex + 1)
                            % Message length is the byte after 'b8', length does
                            % only include the data itself
                            messageLength = dataBuffer(startIndex + 1);
                            if length(dataBuffer) >= (startIndex + messageLength + 2)
                                message = dataBuffer(startIndex:startIndex + messageLength + 2);
                                processedData = [processedData, message];
                                % After finding the data and saving it reset the dataBuffer
                                dataBuffer = uint8([]);
                                measurementCount = measurementCount + 1;
                            else
                                break;
                                % Collect more data!
                            end
                        else
                            break; 
                            % Not enough data for length byte
                        end
                    end
                    % Reset timeout timer after processing data
                    startTime = tic;
                elseif toc(startTime) > timeout
                    disp('Timeout reached without receiving all expected measurements.');
                    break;
                    % Exit loop if timeout is reached
                end
                pause(0.01); 
                % Pause to limit CPU usage
                foundData = processedData;
            end

            if measurementCount >= expectedMeasurements
                disp('Received all expected measurements. Stopping measurement.');
            else
                disp('Did not receive all expected measurements.');
            end
        end

        function writeDataWithHeader(obj, foundData, filename)
            fileId = fopen(filename, 'w');
            if fileId == -1
                error('Failed to open file for writing.');
            end

            fprintf(fileId, 'Current: %f, Start Frequency: %f, End Frequency: %f, Frequencycount: %d, Channels: %d, Log = %s, Patterntype = %s \n', ...
                obj.amplitudeCurrent, ...
                obj.startFrequency, ...
                obj.endFrequency, ...
                obj.frequencyCount, ...
                obj.measurementChannels, ...
                mat2str(obj.useLogFrequencys), ...
                obj.patternType);

            % Process and write the foundData
            while ~isempty(foundData)
                startIdx = double(find(foundData == hex2dec('b8'), 1));
                if isempty(startIdx)
                    break;  % If no b8 found, exit the loop
                end
                if startIdx + 1 > length(foundData)
                    break;  % If there is no byte for message length, exit the loop
                end
                messageLength = double(foundData(startIdx + 1)); 
                if startIdx + 1 + messageLength > length(foundData)
                    break;  % If the full message cannot be obtained, exit the loop
                end
                startIndex = startIdx + 2;  % The start index of the message
                endIndex = startIndex + messageLength - 1;  % The end index of the message

                relevantRows = foundData(startIndex:endIndex);
                stringArray = cellstr(dec2hex(relevantRows));
                lineAccumulator = strjoin(stringArray', ' ');
                fprintf(fileId, '%s\n', lineAccumulator);  % Print the accumulated line

                index = endIndex + 2;
                if index < length(foundData)
                    foundData = foundData(index:end);
                else
                    foundData = [];
                end
            end

            fclose(fileId);  % Close the output file
            disp(['Data written to ', filename]);
        end
    end

    methods (Static)
        function binary = convertToBinary2(val)
            uint16Val = uint16(val);

            % Extract bytes and put them in list
            byte1 = bitshift(bitand(uint16Val, hex2dec('FF00')), -8);
            byte2 = bitand(uint16Val, hex2dec('00FF'));
            binary = [byte1, byte2];
        end

        function binary = convertToBinary4(val)
            uint32Val = uint32(val);

            % Extract the bytes and put them in list
            byte1 = bitshift(uint32Val, -24);
            byte2 = bitshift(bitand(uint32Val, hex2dec('00FF0000')), -16);
            byte3 = bitshift(bitand(uint32Val, hex2dec('0000FF00')), -8);
            byte4 = bitand(uint32Val, hex2dec('000000FF'));
            binary = [byte1, byte2, byte3, byte4];
        end

        function singlePrecisionFloat = toSingleFloat(val)
            singleVal = single(val);
            bytes = typecast(singleVal, 'uint8');

            % Return the bytes in big-endian format
            % MATLAB uses little-endian by default
            singlePrecisionFloat = bytes(end:-1:1);
        end

        function interpretAckCode(ackCode)
            switch ackCode
                case 1
                    disp('Frame-Not-Acknowledge: Incorrect syntax');
                case 2
                    disp('Timeout: Communication-timeout (less data than expected)');
                case 4
                    disp('Wake-Up Message: System boot ready');
                case hex2dec('11')
                    disp('TCP-Socket: Valid TCP client-socket connection');
                case hex2dec('81')
                    disp('Not-Acknowledge: Command has not been executed');
                case hex2dec('82')
                    disp('Not-Acknowledge: Command could not be recognized');
                case hex2dec('83')
                    disp('Command-Acknowledge: Command has been executed successfully');
                case hex2dec('84')
                    disp('System-Ready Message: System is operational and ready to receive data');
                case hex2dec('90')
                    disp('Overcurrent Detected \n Value of DC current on W-ports exceeds capability of configured current range')
                case hex2dec('91')
                    disp('Overvoltage Detected \n Value of DC voltage difference between R and WS port exceeds capability of configured voltage range')
                otherwise
                    disp(['Unknown Acknowledge Code: ', num2str(ackCode)]);
            end
        end

        function writeDataToFile(foundData, filename, lineWidth)
            dataAsString = dec2hex(foundData);

            fileId = fopen(filename, 'w');
            if fileId == -1
                error('Failed to open file for writing.');
            end

            lineAccumulator = '';

            for i = 1:length(foundData)
                lineAccumulator = [lineAccumulator, dataAsString(i,:), ' '];

                if mod(i, lineWidth) == 0 || i == length(foundData)
                    if i == length(foundData)
                        lineAccumulator(end) = '';
                    end
                    fprintf(fileId, '%s\n', lineAccumulator);
                    lineAccumulator = '';
                end
            end

            fclose(fileId);
            disp(['Data written to ', filename]);
        end

        function mustBeInRange(value, low, high)
            if ~isscalar(value) || value < low || value > high
                error('Value must be an integer between %d and %d.', low, high);
            end
        end
        
        function mustBeFile(filePath)
            if ~isfile(filePath)
                eid = 'MATLAB:validators:mustBeFile';
                msg = 'The specified path does not point to a valid file.';
                throwAsCaller(MException(eid, msg));
            end
        end
        
        function mustBeFolder(folderPath)
            if ~isfolder(folderPath)
                eid = 'MATLAB:validators:mustBeFolder';
                msg = 'The specified path does not point to a valid folder.';
                throwAsCaller(MException(eid, msg));
            end
        end
    end
end
