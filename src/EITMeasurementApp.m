classdef EITMeasurementApp < handle
    properties
        fig
        serialPortField
        baudRateField
        currentAmplitudeField
        startFrequencyField
        endFrequencyField
        frequencyCountField
        patternTypeField
        measurementNameField
        numMeasurementsField
        savePathField
        frequencySpacingField
        averagingField
        timeInBetweenField
        precisionField
        statusText

        settingsFilePath = 'eit_measurement_settings.mat';
        defaultParams
        stopFlag = false;

        modelTypeField
        gridSizeField
        priorField
        solverField
        componentTypeField
        frequencyField
        hyperparameterField
        measurementsToReconstruct
        remove2WireCheckbox
        iterationsField

        eidorsPath
        netgenPath
    end

    methods
        function app = EITMeasurementApp()
            % Launch app
            app.defaultParams = struct('serialPort', 'COM3', 'baudRate', 9600, 'currentAmplitude', 40e-6, ...
                'startFrequency', 500, 'endFrequency', 50000, 'frequencyCount', 4, 'patternType', 'Adjacent', ...
                'measurementName', 'Default', 'numMeasurements', 1, 'savePath', 'Test', 'frequencySpacing', 'Linear', ...
                'averaging', 1, 'timeInBetween', 1, 'precision', 1, ...
                'modelType', 'WaterModel', 'gridSize', 1, 'prior', 'laplace', 'solver', 'nodal', ...
                'component', 'complex', 'frequency', '', 'hyperparameter', '0.0007, 0.0006', ...
                'measurementsToReconstruct', 1, 'remove2Wire', true, 'eidorsPath', '', 'netgenPath','','iterations',3);

            if isfile(app.settingsFilePath)
                app.loadParameters();
            else
                app.setDefaultParameters(app.defaultParams);
            end

            % UI setup
            figName = 'EIT Measurement App';
            figPosX = 100;
            figPosY = 100;
            figWidth = 500;
            figHeight = 700;

            app.fig = uifigure('Name', figName, 'Position', [figPosX, figPosY, figWidth, figHeight], ...
                'CloseRequestFcn', @(src, event) app.onCloseApp());

            yPosition = 650;
            labelWidth = 150;
            fieldWidth = 200;
            height = 22;
            spacing = 10;

            % Serial Port
            uilabel(app.fig, 'Position', [20, yPosition, labelWidth, height], 'Text', 'Serial Port:');

            availablePorts = serialportlist("all");
            if isempty(availablePorts)
                availablePorts = {'No Ports Available'};
            end

            % Set default value
            if ismember(app.serialPortField.Value, availablePorts)
                defaultPort = app.serialPortField.Value;
            else
                defaultPort = availablePorts{1};
            end

            app.serialPortField = uidropdown(app.fig, 'Position', [200, yPosition, fieldWidth, height], ...
                'Items', availablePorts, 'Value', defaultPort);

            % Refresh Button
            refreshButton = uibutton(app.fig, 'Position', [fieldWidth + 220, yPosition, 80, 22], 'Text', 'Refresh', ...
                'ButtonPushedFcn', @(btn, event) app.refreshSerialPorts());

            % Baud Rate
            yPosition = yPosition - (height + spacing);
            uilabel(app.fig, 'Position', [20, yPosition, labelWidth, height], 'Text', 'Baud Rate:');
            app.baudRateField = uieditfield(app.fig, 'numeric', 'Position', [200, yPosition, fieldWidth, height], ...
                'Value', app.baudRateField.Value);

            % Current Amplitude
            yPosition = yPosition - (height + spacing);
            uilabel(app.fig, 'Position', [20, yPosition, labelWidth, height], 'Text', 'Current Amplitude (A):');
            app.currentAmplitudeField = uieditfield(app.fig, 'numeric', 'Position', [200, yPosition, fieldWidth, height], ...
                'Value', app.currentAmplitudeField.Value, 'Limits', [10e-6, 10e-3]);

            % Start Frequency
            yPosition = yPosition - (height + spacing);
            uilabel(app.fig, 'Position', [20, yPosition, labelWidth, height], 'Text', 'Start Frequency (Hz):');
            app.startFrequencyField = uieditfield(app.fig, 'numeric', 'Position', [200, yPosition, fieldWidth, height], ...
                'Value', app.startFrequencyField.Value, 'Limits', [0.1, 1e7]);

            % End Frequency
            yPosition = yPosition - (height + spacing);
            uilabel(app.fig, 'Position', [20, yPosition, labelWidth, height], 'Text', 'End Frequency (Hz):');
            app.endFrequencyField = uieditfield(app.fig, 'numeric', 'Position', [200, yPosition, fieldWidth, height], ...
                'Value', app.endFrequencyField.Value, 'Limits', [0.1, 1e7]);

            % Frequency Count
            yPosition = yPosition - (height + spacing);
            uilabel(app.fig, 'Position', [20, yPosition, labelWidth, height], 'Text', 'Frequency Count:');
            app.frequencyCountField = uieditfield(app.fig, 'numeric', 'Position', [200, yPosition, fieldWidth, height], ...
                'Value', app.frequencyCountField.Value, 'Limits', [1, 128]);

            % Frequency Spacing
            yPosition = yPosition - (height + spacing);
            uilabel(app.fig, 'Position', [20, yPosition, labelWidth, height], 'Text', 'Frequency Spacing:');
            app.frequencySpacingField = uidropdown(app.fig, 'Position', [200, yPosition, fieldWidth, height], ...
                'Items', {'Linear', 'Logarithmic'}, 'Value', app.frequencySpacingField.Value);

            % Pattern Type
            yPosition = yPosition - (height + spacing);
            uilabel(app.fig, 'Position', [20, yPosition, labelWidth, height], 'Text', 'Pattern Type:');
            app.patternTypeField = uidropdown(app.fig, 'Position', [200, yPosition, fieldWidth, height], ...
                'Items', {'Adjacent', 'Diagonal', 'Opposite', 'Hybrid', 'Montgomery'}, 'Value', app.patternTypeField.Value);

            % Info button
            infoIconPath = fullfile('src', 'patterns', 'info.png');
            uibutton(app.fig, 'Position', [fieldWidth + 220, yPosition, 30, 30], 'Text', '', ...
                'Icon', infoIconPath, 'ButtonPushedFcn', @(btn, event) app.showPatternInfo());

            % Precision
            yPosition = yPosition - (height + spacing);
            uilabel(app.fig, 'Position', [20, yPosition, labelWidth, height], 'Text', 'Precision:');
            app.precisionField = uieditfield(app.fig, 'numeric', 'Position', [200, yPosition, fieldWidth, height], ...
                'Value', app.precisionField.Value, 'Limits', [1, 5]);

            % Measurement Group
            yPosition = yPosition - (height + 4 * spacing);

            % Measurement Name
            uilabel(app.fig, 'Position', [20, yPosition, labelWidth, height], 'Text', 'Measurement Name:');
            app.measurementNameField = uieditfield(app.fig, 'text', 'Position', [200, yPosition, fieldWidth, height], ...
                'Value', app.measurementNameField.Value);

            % Number of Measurements
            yPosition = yPosition - (height + spacing);
            uilabel(app.fig, 'Position', [20, yPosition, labelWidth, height], 'Text', 'Number of Measurements:');
            app.numMeasurementsField = uieditfield(app.fig, 'numeric', 'Position', [200, yPosition, fieldWidth, height], ...
                'Value', app.numMeasurementsField.Value);

            % Save Path
            yPosition = yPosition - (height + spacing);
            uilabel(app.fig, 'Position', [20, yPosition, labelWidth, height], 'Text', 'Save Path:');
            app.savePathField = uieditfield(app.fig, 'text', 'Position', [200, yPosition, fieldWidth, height], ...
                'Value', app.savePathField.Value);

            % Time Between Measurements
            yPosition = yPosition - (height + spacing);
            uilabel(app.fig, 'Position', [20, yPosition, labelWidth, height], 'Text', 'Time Between Measurements (s):');
            app.timeInBetweenField = uieditfield(app.fig, 'numeric', 'Position', [200, yPosition, fieldWidth, height], ...
                'Value', app.timeInBetweenField.Value, 'Limits', [0, 1000]);

            % Averaging Count
            yPosition = yPosition - (height + spacing);
            uilabel(app.fig, 'Position', [20, yPosition, labelWidth, height], 'Text', 'Averaging Count:');
            app.averagingField = uieditfield(app.fig, 'numeric', 'Position', [200, yPosition, fieldWidth, height], ...
                'Value', app.averagingField.Value, 'Limits', [1, 100]);

            % Buttons
            buttonWidth = 140;
            buttonHeight = 30;
            buttonSpacingX = (app.fig.Position(3) - 2 * buttonWidth) / 3;
            buttonSpacingY = 10;
            buttonStartX = buttonSpacingX;
            buttonStartY = 150;

            uibutton(app.fig, 'Position', [buttonStartX, buttonStartY, buttonWidth, buttonHeight], 'Text', 'Test Connection', ...
                'ButtonPushedFcn', @(btn, event) app.testConnectionCallback());

            uibutton(app.fig, 'Position', [buttonStartX + buttonWidth + buttonSpacingX, buttonStartY, buttonWidth, buttonHeight], 'Text', 'Run Measurement', ...
                'ButtonPushedFcn', @(btn, event) app.runMeasurementCallback());

            uibutton(app.fig, 'Position', [buttonStartX, buttonStartY - buttonHeight - buttonSpacingY, buttonWidth, buttonHeight], 'Text', 'Continuous', ...
                'ButtonPushedFcn', @(btn, event) app.continuousMeasurementCallback());

            uibutton(app.fig, 'Position', [buttonStartX + buttonWidth + buttonSpacingX, buttonStartY - buttonHeight - buttonSpacingY, buttonWidth, buttonHeight], 'Text', 'Visualize Results', ...
                'ButtonPushedFcn', @(btn, event) app.visualizeResultsCallback());

            app.statusText = uitextarea(app.fig, 'Position', [20, 20, 360, 60], 'Editable', 'off', 'Value', 'Status: Initializing EIDORS...');

            if isempty(app.eidorsPath) || ~isfolder(app.eidorsPath) || ~exist(fullfile(app.eidorsPath, 'startup.m'), 'file')
                app.eidorsPath = uigetdir(pwd, 'Select EIDORS Directory');
                if app.eidorsPath == 0
                    error('EIDORS path is required to run the application.');
                end
                app.saveParameters();
            end

            if ismac
                if isempty(app.netgenPath) || ~isfolder(app.netgenPath) || ~exist(fullfile(app.netgenPath, 'netgen'), 'file')
                    app.netgenPath = uigetdir(pwd, 'Select Netgen Directory');
                    if app.netgenPath == 0
                        error('Netgen path is required to run the application on macOS.');
                    end
                    app.saveParameters();
                end
            else
                app.netgenPath = '';
            end

            app.initializeEidors();
        end

        function initializeEidors(app)
            % Initialize EIDORS
            eidorsStartupPath = fullfile(app.eidorsPath, 'startup.m');
            netgenDirPath = app.netgenPath;

            if exist(eidorsStartupPath, 'file')
                app.setup_eidors(eidorsStartupPath, netgenDirPath);
            else
                warning('EIDORS startup.m file not found in the specified path.');
            end
            app.statusText.Value = 'EIDORS initialized. Ready to use.';
        end

        function setDefaultParameters(app, defaultParams)
            % default params for measurement
            app.serialPortField.Value = defaultParams.serialPort;
            app.baudRateField.Value = defaultParams.baudRate;
            app.currentAmplitudeField.Value = defaultParams.currentAmplitude;
            app.startFrequencyField.Value = defaultParams.startFrequency;
            app.endFrequencyField.Value = defaultParams.endFrequency;
            app.frequencyCountField.Value = defaultParams.frequencyCount;
            app.patternTypeField.Value = defaultParams.patternType;
            app.measurementNameField.Value = defaultParams.measurementName;
            app.numMeasurementsField.Value = defaultParams.numMeasurements;
            app.savePathField.Value = defaultParams.savePath;
            app.frequencySpacingField.Value = defaultParams.frequencySpacing;
            app.averagingField.Value = defaultParams.averaging;
            app.timeInBetweenField.Value = defaultParams.timeInBetween;
            app.precisionField.Value = defaultParams.precision;
            

            % default params for reconstruction
            app.modelTypeField.Value = defaultParams.modelType;
            app.gridSizeField.Value = defaultParams.gridSize;
            app.priorField.Value = defaultParams.prior;
            app.solverField.Value = defaultParams.solver;
            app.componentTypeField.Value = defaultParams.component;
            app.frequencyField.Value = defaultParams.frequency;
            app.hyperparameterField.Value = defaultParams.hyperparameter;
            app.measurementsToReconstruct.Value = defaultParams.measurementsToReconstruct;
            app.remove2WireCheckbox.Value = defaultParams.remove2Wire;
            app.iterationsField.Value = defaultParams.iterations;
        end

        function loadParameters(app)
            % Load parameter values from file if it exists
            if isfile(app.settingsFilePath)
                loadedData = load(app.settingsFilePath, 'params');
                params = loadedData.params;

                app.serialPortField.Value = params.serialPort;
                app.baudRateField.Value = params.baudRate;
                app.currentAmplitudeField.Value = params.currentAmplitude;
                app.startFrequencyField.Value = params.startFrequency;
                app.endFrequencyField.Value = params.endFrequency;
                app.frequencyCountField.Value = params.frequencyCount;
                app.patternTypeField.Value = params.patternType;
                app.measurementNameField.Value = params.measurementName;
                app.numMeasurementsField.Value = params.numMeasurements;
                app.savePathField.Value = params.savePath;
                app.frequencySpacingField.Value = params.frequencySpacing;
                app.averagingField.Value = params.averaging;
                app.timeInBetweenField.Value = params.timeInBetween;
                app.precisionField.Value = params.precision;

                app.modelTypeField.Value = params.modelType;
                app.gridSizeField.Value = params.gridSize;
                app.priorField.Value = params.prior;
                app.solverField.Value = params.solver;
                app.componentTypeField.Value = params.component;
                app.frequencyField.Value = params.frequency;
                app.hyperparameterField.Value = params.hyperparameter;
                app.measurementsToReconstruct.Value = params.measurementsToReconstruct;
                app.remove2WireCheckbox.Value = params.remove2Wire;
                app.iterationsField.Value = params.iterationsField;
                app.eidorsPath = params.eidorsPath;
                app.netgenPath = params.netgenPath;
            else
                app.setDefaultParameters(app.defaultParams);
            end
        end

        function onCloseApp(app)
            app.saveParameters();
            delete(app.fig);
        end

        function saveParameters(app)
            % Save measurement settings
            params.serialPort = app.serialPortField.Value;
            params.baudRate = app.baudRateField.Value;
            params.currentAmplitude = app.currentAmplitudeField.Value;
            params.startFrequency = app.startFrequencyField.Value;
            params.endFrequency = app.endFrequencyField.Value;
            params.frequencyCount = app.frequencyCountField.Value;
            params.patternType = app.patternTypeField.Value;
            params.measurementName = app.measurementNameField.Value;
            params.numMeasurements = app.numMeasurementsField.Value;
            params.savePath = app.savePathField.Value;
            params.frequencySpacing = app.frequencySpacingField.Value;
            params.averaging = app.averagingField.Value;
            params.timeInBetween = app.timeInBetweenField.Value;
            params.precision = app.precisionField.Value;

            % Save reconstruction settings
            params.modelType = app.modelTypeField.Value;
            params.gridSize = app.gridSizeField.Value;
            params.prior = app.priorField.Value;
            params.solver = app.solverField.Value;
            params.component = app.componentTypeField.Value;
            params.frequency = app.frequencyField.Value;
            params.hyperparameter = app.hyperparameterField.Value;
            params.measurementsToReconstruct = app.measurementsToReconstruct.Value;
            params.remove2Wire = app.remove2WireCheckbox.Value;
            params.iterationsField = app.iterationsField.Value;

            params.eidorsPath = app.eidorsPath;
            params.netgenPath = app.netgenPath;
            save(app.settingsFilePath, 'params');
        end


        function continuousMeasurementCallback(app)
            % settings for continuous measurement
            settingsFig = uifigure('Name', 'Continuous Measurement Settings', 'Position', [150 150 400 450]);

            uilabel(settingsFig, 'Position', [20 370 150 22], 'Text', 'Select Model:');
            app.modelTypeField = uidropdown(settingsFig, 'Position', [170 370 200 22], ...
                'Items', {'WaterModel', 'ElastomerModel'}, 'Value', app.modelTypeField.Value);

            uilabel(settingsFig, 'Position', [20 330 150 22], 'Text', 'Grid Size:');
            app.gridSizeField = uieditfield(settingsFig, 'numeric', 'Position', [170 330 200 22], ...
                'Value', app.gridSizeField.Value, 'Limits', [0.1, 10]);

            uilabel(settingsFig, 'Position', [20 290 150 22], 'Text', 'Select Prior:');
            app.priorField = uidropdown(settingsFig, 'Position', [170 290 200 22], ...
                'Items', {'laplace', 'noser', 'tikhonov', 'gaussian', 'TV'}, 'Value', app.priorField.Value);

            uilabel(settingsFig, 'Position', [20 250 150 22], 'Text', 'Select Solver:');
            app.solverField = uidropdown(settingsFig, 'Position', [170 250 200 22], ...
                'Items', {'Nodal', 'Gauss-Newton-ON', 'Gauss-Newton-iterative', 'Dual', 'TV'}, 'Value', app.solverField.Value);

            uilabel(settingsFig, 'Position', [20 210 150 22], 'Text', 'Component Type:');
            app.componentTypeField = uidropdown(settingsFig, 'Position', [170 210 200 22], ...
                'Items', {'complex', 'imaginary', 'real'}, 'Value', app.componentTypeField.Value);

            uilabel(settingsFig, 'Position', [20 170 150 22], 'Text', 'Hyperparameters:');
            app.hyperparameterField = uieditfield(settingsFig, 'text', 'Position', [170 170 200 22], ...
                'Value', app.hyperparameterField.Value);

            startButton = uibutton(settingsFig, 'Position', [50 40 100 30], 'Text', 'Start Measurement', ...
                'ButtonPushedFcn', @(btn,event) app.startContinuousMeasurement());

            stopButton = uibutton(settingsFig, 'Position', [250 40 100 30], 'Text', 'Stop Measurement', ...
                'ButtonPushedFcn', @(btn,event) app.stopContinuousMeasurement());

            app.statusText.Value = 'Select settings for continuous measurement.';
        end


        function stopContinuousMeasurement(app)
            app.stopFlag = true;
            app.statusText.Value = 'Stopping measurement...';
            drawnow;
        end

        function saveSettingsOnClose(app, src)
            try
                app.saveParameters();
                delete(src);
            catch ME
                warning('%s: %s', ME.identifier, ME.message);
            end
        end

        function startContinuousMeasurement(app)
            try
                serialPort = app.serialPortField.Value;
                baudRate = app.baudRateField.Value;
                currentAmplitude = app.currentAmplitudeField.Value;
                startFrequency = app.startFrequencyField.Value;
                endFrequency = app.endFrequencyField.Value;
                frequencyCount = app.frequencyCountField.Value;
                patternType = app.patternTypeField.Value;
                measurementName = app.measurementNameField.Value;
                numMeasurements = app.numMeasurementsField.Value;
                savePath = app.savePathField.Value;
                frequencySpacing = app.frequencySpacingField.Value;
                precision = app.precisionField.Value;
                averaging = app.averagingField.Value;

                modelType = app.modelTypeField.Value;
                gridSize = app.gridSizeField.Value;
                priorType = app.priorField.Value;
                solverType = app.solverField.Value;
                componentType = app.componentTypeField.Value;
                hyperparameters = strsplit(app.hyperparameterField.Value, ',');
                hyperparameterValues = cellfun(@(x) str2double(x), hyperparameters, 'UniformOutput', false);

                app.statusText.Value = 'Running Continuous EIT Measurement...';
                drawnow;

                useLog = strcmp(frequencySpacing, 'Logarithmic');

                measurementNames = arrayfun(@(x) sprintf('%s_%d', measurementName, x), 1:numMeasurements, 'UniformOutput', false);

                e = EIT();
                e = e.setupScioSpecConnection(serialPort, baudRate);
                e = e.configureConnectionHandler(1, currentAmplitude, startFrequency, endFrequency, frequencyCount, useLog, precision, 16, patternType);
                e = e.setSavePath(savePath);
                e.connectionHandler.sendEITSetup();

                currentDateTime = datetime('now', 'Format', 'yyyy-MM-dd_HH-mm-ss');
                baseFolderName = fullfile(savePath, patternType, char(currentDateTime));
                mkdir(baseFolderName);

                filePath = fullfile(baseFolderName, measurementNames{1});

                baselineSumMatrix = struct();
                avMatrix = 0;
                for i = 1:averaging
                    [curBaseMatrix, ~, ~, channels, inputChannels, outputChannels, ~, ~] = e.continousMeasurement(filePath);
                    frequencies = fieldnames(curBaseMatrix);
                    f = frequencies{1};
                    matrix = curBaseMatrix.(f);
                    avMatrix = avMatrix + matrix;
                    fprintf('Baseline measurement %d completed.\n', i);
                end
                avMatrix = avMatrix / averaging;
                baselineSumMatrix.(f)= avMatrix;
                disp('Averaged baseline measurement completed.');

                if strcmp(modelType, 'WaterModel')
                    fwdModel = Model.getWaterModel(gridSize);
                else
                    fwdModel = Model.getElastomerModel(gridSize);
                end

                fwdModel = Model.setStimulation(fwdModel, inputChannels, outputChannels, channels, currentAmplitude, true);

                bMatrix = Data.convertToAdjacentMatrixForFirstFrequency(baselineSumMatrix);
                baseLineVec = Reconstruction.buildEidorsDataForMeasurement(bMatrix, measurementNames{1}, componentType, fwdModel);

                disp('Baseline measurement completed.');

                if isempty(gcp('nocreate'))
                    parpool('local');
                end

                app.stopFlag = false;
                for i = 2:numMeasurements
                    if app.stopFlag
                        app.statusText.Value = 'Measurement stopped by user.';
                        break;
                    end

                    filePath = fullfile(baseFolderName, measurementNames{i});
                    app.statusText.Value = sprintf('Running Measurement %d of %d...', i, numMeasurements);
                    drawnow;

                    curMatrix = e.continousMeasurement(filePath);
                    curMatrix = Data.convertToAdjacentMatrixForFirstFrequency(curMatrix);
                    curVec = Reconstruction.buildEidorsDataForMeasurement(curMatrix, measurementNames{i}, componentType, fwdModel);
                    fprintf('Measurement %d completed.\n', i);

                    app.updateSinglePlotWithMeasurement(curVec, baseLineVec, fwdModel, priorType, solverType, hyperparameterValues);
                end

                if ~app.stopFlag
                    app.statusText.Value = 'Continuous EIT Measurement Completed.';
                end

            catch ME
                warning('%s: %s', ME.identifier, ME.message);
            end
        end

        function updateSinglePlotWithMeasurement(app, curEidorsData, baseLineEidorsData, fwdModel, priorType, solverType, hyperparameterValues)
            persistent fig ax solver prior hyperparameter invModel data1

            try
                if isempty(fig) || ~isvalid(fig)
                    fig = figure('Name', 'EIT Reconstruction', 'NumberTitle', 'off', 'Visible', 'on');
                    ax = axes(fig);
                    hold(ax, 'on');

                    disp('Figure and axes created for EIT Reconstruction.');

                    prior = Reconstruction.setPriors(priorType);
                    solver = Reconstruction.setSolver(solverType);
                    hyperparameter = hyperparameterValues{1};

                    disp(['Prior type: ', priorType, ', Solver type: ', solverType, ', Hyperparameter: ', num2str(hyperparameter)]);

                    invModel = Reconstruction.createInverseModel(1, solver{1}, prior{1}, hyperparameter, fwdModel, 1);

                    data1 = baseLineEidorsData;
                end

                imgr = inv_solve(invModel, data1, curEidorsData);

                disp('Inverse solve completed.');

                cla(ax);
                Reconstruction.plotDataField(imgr, fwdModel);
                colorbar(ax);
                title(ax, 'Updated Reconstruction', 'FontSize', 16);

                drawnow;

                app.statusText.Value = 'Reconstruction updated.';
                disp('Reconstruction updated.');

            catch ME
                warning('%s: %s', ME.identifier, ME.message);
            end
        end

        function runMeasurementCallback(app)
            try
                serialPort = app.serialPortField.Value;
                baudRate = app.baudRateField.Value;
                currentAmplitude = app.currentAmplitudeField.Value;
                startFrequency = app.startFrequencyField.Value;
                endFrequency = app.endFrequencyField.Value;
                frequencyCount = app.frequencyCountField.Value;
                patternType = app.patternTypeField.Value;
                measurementName = app.measurementNameField.Value;
                numMeasurements = app.numMeasurementsField.Value;
                savePath = app.savePathField.Value;
                frequencySpacing = app.frequencySpacingField.Value;
                averaging = app.averagingField.Value;
                timeInBetween = app.timeInBetweenField.Value;
                precision = app.precisionField.Value;

                app.statusText.Value = 'Running EIT Measurement...';
                drawnow;

                useLog = strcmp(frequencySpacing, 'Logarithmic');

                measurementNames = arrayfun(@(x) sprintf('%s_%d', measurementName, x), 1:numMeasurements, 'UniformOutput', false);

                e = EIT();
                e = e.setupScioSpecConnection(serialPort, baudRate);
                e = e.configureConnectionHandler(1, currentAmplitude, startFrequency, endFrequency, frequencyCount, useLog, precision, 16, patternType);

                e = e.setSavePath(savePath);

                e.startPatternedMeasurement(savePath, measurementNames, averaging, timeInBetween, measurementName);

                app.statusText.Value = 'Measurement completed.';

            catch ME
                errorMessage = sprintf('An error occurred:\n%s', ME.message);
                app.statusText.Value = errorMessage;
                disp(errorMessage);
            end
        end

        function showPatternInfo(app)
            selectedPattern = app.patternTypeField.Value;

            imageFolder = fullfile('src','patterns');
            switch selectedPattern
                case 'Adjacent'
                    imagePath = fullfile(imageFolder, 'adjacent.png');
                case 'Diagonal'
                    imagePath = fullfile(imageFolder, 'diagonal.png');
                case 'Opposite'
                    imagePath = fullfile(imageFolder, 'opposite.png');
                case 'Hybrid'
                    imagePath = fullfile(imageFolder, 'hybrid.png');
                case 'Montgomery'
                    imagePath = '';
            end

            if ~isempty(imagePath) && isfile(imagePath)
                patternFig = uifigure('Name', sprintf('%s Pattern', selectedPattern), 'Position', [100, 100, 400, 400]);
                uiimage(patternFig, 'ImageSource', imagePath, 'Position', [10, 10, 380, 380]);

            else
                uialert(app.fig, 'No image available for the selected pattern type.', 'Info');
            end
        end

        function testConnectionCallback(app)
            try
                serialPort = app.serialPortField.Value;
                baudRate = app.baudRateField.Value;
                currentAmplitude = app.currentAmplitudeField.Value;
                startFrequency = app.startFrequencyField.Value;
                endFrequency = app.endFrequencyField.Value;
                frequencyCount = app.frequencyCountField.Value;
                patternType = app.patternTypeField.Value;
                measurementName = app.measurementNameField.Value;
                numMeasurements = app.numMeasurementsField.Value;
                savePath = app.savePathField.Value;
                frequencySpacing = app.frequencySpacingField.Value;
                precision = app.precisionField.Value;

                useLog = strcmp(frequencySpacing, 'Logarithmic');
                e = EIT();
                e = e.setupScioSpecConnection(serialPort, baudRate);
                e = e.configureConnectionHandler(1, currentAmplitude, startFrequency, endFrequency, frequencyCount, useLog, precision, 16, patternType);
                e = e.setSavePath(checkAndCreateSavePath(app.savePathField.Value));
                doNotPlot = true;
                e.analyzeMultiplePatternedMeasurements(savePath, numMeasurements, patternType, measurementName, savePath, doNotPlot);
                app.statusText.Value = 'Analyzing!';
            catch ME
                app.statusText.Value = sprintf('Connection failed: %s', ME.message);
            end
            drawnow;
        end

        function visualizeResultsCallback(app)
            % Open a new window for choosing reconstruction settings
            height = 540;
            labelHeight = 40;
            settingsFig = uifigure('Name', 'Reconstruction Settings', 'Position', [150 150 400 height], ...
                'CloseRequestFcn', @(src, event) app.saveSettingsOnClose(src));
            height = height - labelHeight;
            % Create UI elements for reconstruction settings
            uilabel(settingsFig, 'Position', [20 height 150 22], 'Text', 'Select Model:');
            app.modelTypeField = uidropdown(settingsFig, 'Position', [170 height 200 22], 'Items', {'WaterModel', 'ElastomerModel'}, 'Value', 'WaterModel');
            
            height = height - labelHeight;
            uilabel(settingsFig, 'Position', [20 height 150 22], 'Text', 'Grid Size:');
            app.gridSizeField = uieditfield(settingsFig, 'numeric', 'Position', [170 height 200 22], 'Value', 1, 'Limits', [0.1, 10]);
            
            height = height - labelHeight;
            uilabel(settingsFig, 'Position', [20 height 150 22], 'Text', 'Select Prior:');
            app.priorField = uidropdown(settingsFig, 'Position', [170 height 200 22], 'Items', {'laplace', 'noser', 'tikhonov', 'gaussian', 'TV'}, 'Value', 'laplace');

            height = height - labelHeight;
            uilabel(settingsFig, 'Position', [20 height 150 22], 'Text', 'Select Solver:');
            app.solverField = uidropdown(settingsFig, 'Position', [170 height 200 22], 'Items',{'Nodal', 'Gauss-Newton-ON', 'Gauss-Newton-iterative', 'Dual', 'TV', 'Value', 'Nodal'});

            height = height - labelHeight;
            uilabel(settingsFig, 'Position', [20 height 150 22], 'Text', 'Component Type:');
            app.componentTypeField = uidropdown(settingsFig, 'Position', [170 height 200 22], 'Items', {'complex', 'imaginary', 'real'}, 'Value', 'complex');

            height = height - labelHeight;
            uilabel(settingsFig, 'Position', [20 height 150 22], 'Text', 'Select Frequency:');
            app.frequencyField = uidropdown(settingsFig, 'Position', [170 height 200 22], 'Items', {});

            height = height - labelHeight;
            uilabel(settingsFig, 'Position', [20 height 150 22], 'Text', 'Hyperparameters:');
            app.hyperparameterField = uieditfield(settingsFig, 'text', 'Position', [170 height 200 22], 'Value', '0.0007, 0.0006');

            height = height - labelHeight;
            uilabel(settingsFig, 'Position', [20 height 150 22], 'Text', 'No. of Measurements:');
            app.measurementsToReconstruct = uieditfield(settingsFig, 'numeric', 'Position', [170 height 200 22], 'Value', 1, 'Limits', [1, 100]);

            height = height - labelHeight;
            uilabel(settingsFig, 'Position', [20 height 150 22], 'Text', 'Save Path:');
            app.savePathField = uieditfield(settingsFig, 'text', 'Position', [170 height 200 22], 'Value', 'Plots');

            height = height - labelHeight;
            uilabel(settingsFig, 'Position', [20 height 150 22], 'Text', 'Iterations:');
            app.iterationsField = uieditfield(settingsFig, 'numeric', 'Position', [170 height 200 22], 'Value', 3);

            height = height - labelHeight;
            app.remove2WireCheckbox = uicheckbox(settingsFig, 'Position', [20 height 350 22], 'Text', 'Remove 2-Wire Measurements', 'Value', false);
    

            app.statusText.Value = 'Loading measurement data...';
            drawnow;

            try
                path = selectMeasurementDirectory(fullfile(pwd));
                if isempty(path) || isequal(path, 0)
                    app.statusText.Value = 'No folder selected. Operation cancelled.';
                    return;
                end
    
                [measurement, params] = parseMeasurementFile(path, false);
    
                availableFrequencies = params.MeasurementFrequencies;
                if ~isempty(availableFrequencies)
                    frequencyItems = cellfun(@num2str, num2cell(availableFrequencies), 'UniformOutput', false);
                    app.frequencyField.Items = frequencyItems;
                    app.frequencyField.Value = frequencyItems{1};
                else
                    app.frequencyField.Items = {};
                    app.frequencyField.Value = '';
                end
    
                availableMeasurements = length(params.MeasurementNames);
                app.measurementsToReconstruct.Value = availableMeasurements;
    
                plotButton = uibutton(settingsFig, 'Position', [150 40 100 30], 'Text', 'Plot', ...
                    'ButtonPushedFcn', @(btn,event) app.plotAllMeasurementsCallback(measurement, params));
    
                visualizeModelButton = uibutton(settingsFig, 'Position', [30 40 100 30], 'Text', 'Visualize Model', ...
                    'ButtonPushedFcn', @(btn,event) app.visualizeModelCallback());
    
                app.statusText.Value = 'Measurement data loaded. Please select settings for visualization.';
                catch ME
                    app.statusText.Value = ['Error: ', ME.message];
            end
        end

        function plotAllMeasurementsCallback(app, measurement, params)
            modelType = app.modelTypeField.Value;
            gridSize = app.gridSizeField.Value;
            priorType = app.priorField.Value;
            solverType = app.solverField.Value;
            componentType = app.componentTypeField.Value;
            selectedFrequency = str2double(app.frequencyField.Value);
            hyperparameters = strsplit(app.hyperparameterField.Value, ',');
            numMeasurements = app.measurementsToReconstruct.Value;
            hyperparameterValues = cellfun(@(x) str2double(x), hyperparameters, 'UniformOutput', false);
            iterations = app.iterationsField.Value;

            savePath = checkAndCreateSavePath(app.savePathField.Value);

            app.statusText.Value = 'Loading data and visualizing results...';
            drawnow;

            inputChannels = params.InputChannels;
            outputChannels = params.OutputChannels;
            current = params.MeasurementCurrent;
            frequencies = params.MeasurementFrequencies;
            channels = params.MeasurementChannels;
            measurements = Data.convertAllToAdjacent(measurement);

            switch modelType
                case 'WaterModel'
                    fwdModel = Model.getWaterModel(gridSize);
                case 'ElastomerModel'
                    fwdModel = Model.getElastomerModel(gridSize);
            end

            fwdModel = Model.setStimulation(fwdModel, inputChannels, outputChannels, channels, current, app.remove2WireCheckbox.Value);

            frequencyIndex = find(frequencies == selectedFrequency, 1);
            if isempty(frequencyIndex)
                app.statusText.Value = 'Selected frequency is not valid.';
                return;
            end

            eidorsData = Reconstruction.createEidorsData(measurements, params, frequencyIndex, componentType, fwdModel);

            priors = Reconstruction.setPriors(priorType);
            solvers = Reconstruction.setSolver(solverType);

            Reconstruction.plotAllMeasurements(eidorsData, numMeasurements, solvers, priors, hyperparameterValues, fwdModel, savePath, iterations);

            app.statusText.Value = 'Visualization completed.';
        end

        function visualizeModelCallback(app)
            modelType = app.modelTypeField.Value;
            gridSize = app.gridSizeField.Value;

            switch modelType
                case 'WaterModel'
                    fwdModel = Model.getWaterModel(gridSize);
                case 'ElastomerModel'
                    fwdModel = Model.getElastomerModel(gridSize);
            end
            Model.visualizeModel(fwdModel);

            app.statusText.Value = sprintf('Visualized %s model.', modelType);
        end

    end

    methods (Access = private)
        function setup_eidors(app, eidorsStartupPath, netgenDirPath)
            try
                run(eidorsStartupPath);
            catch ME
                error('Failed to run EIDORS startup script: %s', ME.message);
            end

            if ismac
                try
                    setenv('NETGENDIR', netgenDirPath);
                    setenv('PATH', [netgenDirPath, ':', getenv('PATH')]);
                catch ME
                    error('Failed to set Netgen environment variables: %s', ME.message);
                end
            end

            try
                eidors_cache('cache_size', 10*1024*1024*1024);
            catch ME
                error('Failed to set EIDORS cache size: %s', ME.message);
            end

            app.statusText.Value = 'EIDORS initialized successfully.';
        end

        function refreshSerialPorts(app)
            availablePorts = serialportlist("all");
            if isempty(availablePorts)
                availablePorts = {'No Ports Available'};
            end

            app.serialPortField.Items = availablePorts;

            if ismember(app.serialPortField.Value, availablePorts)
                app.serialPortField.Value = app.serialPortField.Value;
            else
                app.serialPortField.Value = availablePorts{1};
            end

            app.statusText.Value = 'Serial ports list refreshed.';
        end
    end
end