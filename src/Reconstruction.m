classdef Reconstruction
    methods (Static)
        function eidorsData = createEidorsData(data, params, frequencyIndex, mode, fwdModel)
            % Create EIDORS data for a specific frequency.
            frequencies = params.MeasurementFrequencies;
            measurementNames = params.MeasurementNames;
            Reconstruction.validateFrequencyIndex(frequencyIndex, frequencies);
            frequencyKey = sprintf('Freq%d', round(frequencies(frequencyIndex)));
            eidorsData = Reconstruction.buildEIDORSData(data, measurementNames, frequencyKey, mode, fwdModel);
        end

        function eidorsDataForTime = createEIDORSDataForTime(data, params, timeIndex, mode, fwdModel)
            % Create EIDORS data for a specific time index.
            measurementNames = params.MeasurementNames;

            if timeIndex < 1 || timeIndex > length(measurementNames)
                error('Time index is out of bounds.');
            end
            measurementName = measurementNames{timeIndex};
            if ~isfield(data, measurementName)
                error('Measurement data not available for the specified time index.');
            end
        
            measurementData = data.(measurementName);
            eidorsDataForTime = {};
            frequencyFields = fieldnames(measurementData);
            for i = 1:length(frequencyFields)
                frequencyKey = frequencyFields{i};
                dataMatrix = measurementData.(frequencyKey);
                dataVec = Reconstruction.transformMeasurementData(dataMatrix, mode);
                identifier = sprintf('%s_%s', measurementName, frequencyKey);
                eidorsDataObj = eidors_obj('data', identifier, 'meas', dataVec, 'fwd_model', fwdModel);
                eidorsDataForTime{end+1} = eidorsDataObj;
            end
        end

        function dataVec = transformMeasurementData(dataMatrix, componentType)
            % Transform measurement data based on the specified component type.
            switch componentType
                case 'imaginary'
                    dataMatrix = imag(dataMatrix);
                case 'real'
                    dataMatrix = real(dataMatrix);
                case 'complex'
                    % Do nothing for complex data.
                otherwise
                    error('Invalid componentType specified.');
            end
            dataVec = dataMatrix';
            dataVec = dataVec(:);
        end

        function startTimeDifferenceEIT(eidorsData, solvers, priors, hyperparameter_values, fwdModel, savePath, iterations)
            % Start time difference EIT reconstruction.
            config = Reconstruction.generateReconstructionConfig(eidorsData, solvers, priors, hyperparameter_values);
            for i = 1:length(config)
                cfg = config(i);
                Reconstruction.performReconstructionAndVisualize(eidorsData, cfg.dataIdx, cfg.solverIdx, cfg.priorIdx, cfg.hyperIdx, solvers, priors, hyperparameter_values, savePath, fwdModel, iterations);
            end
        end

        function startFrequencyDifferenceEIT(data, params, timeIndex, mode, solvers, priors, hyperparameter_values, fwdModel, savePath, iterations)
            % Start frequency difference EIT reconstruction.
            eidorsDataForTime = Reconstruction.createEIDORSDataForTime(data, params, timeIndex, mode, fwdModel);
            config = Reconstruction.generateReconstructionConfig(eidorsDataForTime, solvers, priors, hyperparameter_values);
            for i = 1:length(config)
                cfg = config(i);
                Reconstruction.performReconstructionAndVisualize(eidorsDataForTime, cfg.dataIdx, cfg.solverIdx, cfg.priorIdx, cfg.hyperIdx, solvers, priors, hyperparameter_values, savePath, fwdModel, iterations);
            end
        end

        function priors = setPriors(varargin)
            % Set the priors for the reconstruction.
            availablePriors = struct(...
                'noser', @prior_noser, ...
                'laplace', @prior_laplace, ...
                'tikhonov', @prior_tikhonov, ...
                'gaussian', @prior_gaussian_HPF, ...
                'TV', @prior_TV, ...
                'bayesian', @prior_gaussian_Hyperparameter ...
            );

            if nargin == 1 && ischar(varargin{1}) && strcmp(varargin{1}, 'all')
                priors = struct2cell(availablePriors);
            else
                priors = {};
                for i = 1:length(varargin)
                    priorName = varargin{i};
                    if isfield(availablePriors, priorName)
                        priors{end+1} = availablePriors.(priorName);
                    else
                        error('Invalid prior name: %s', priorName);
                    end
                end
            end
        end

        function solvers = setSolver(solver)
            % Set the solvers for the reconstruction.
            % 'Nodal', 'Gauss-Newton-ON','Gauss-Newton-iterative', 'PDIM', 'TV'}
            if solver == "Gauss-Newton-ON"
                solvers = {@inv_solve_diff_GN_one_step};
            elseif solver == "Gauss-Newton-iterative"
                solvers = {@inv_solve_gn};
            elseif solver == "Dual"
                solvers = {@inv_solve_diff_pdipm};
            elseif solver == "Nodal"
                solvers = {@nodal_solve};
            elseif solver == "TV"
                solvers = {@inv_solve_TV_pdipm};
            else
                error('Invalid solver name: %s', solver);
            end
        end

        function validateFrequencyIndex(frequencyIndex, frequencies)
            % Validate the frequency index to ensure it is within bounds.
            if frequencyIndex < 1 || frequencyIndex > length(frequencies)
                error('Reconstruction:InvalidFrequencyIndex', ...
                      'Frequency index %d is out of bounds.', frequencyIndex);
            end
        end

        function eidorsData = buildEIDORSData(data, measurementNames, frequencyKey, mode, fwdModel)
            % Build EIDORS data for the given measurement names and frequency key.
            eidorsData = {};
            for nameIdx = 1:length(measurementNames)
                measurementName = measurementNames{nameIdx};
                measurementEntry = data.(measurementName);
                if isfield(measurementEntry, frequencyKey)
                    dataMatrix = measurementEntry.(frequencyKey);
                    dataVec = Reconstruction.transformMeasurementData(dataMatrix, mode);
                    identifier = sprintf('%s_%s', measurementName, frequencyKey);
                    eidorsData{end+1} = eidors_obj('data', identifier, 'meas', dataVec, 'fwd_model', fwdModel);
                else
                    warning('Reconstruction:FrequencyNotFound', ...
                            'Frequency %s not found in measurement %s.', frequencyKey, measurementName);
                end
            end
        end

        function eidorsData = buildEidorsDataForMeasurement(data, measurementName, mode, fwdModel)
            % Build EIDORS data for the given measurement names and frequency key.
            frequencies = fieldnames(data);
            frequencyKey = frequencies{1};
            if isfield(data, frequencyKey)
                dataMatrix = data.(frequencyKey);
                dataVec = Reconstruction.transformMeasurementData(dataMatrix, mode);
                identifier = sprintf('%s_%s', measurementName, frequencyKey);
                eidorsData = eidors_obj('data', identifier, 'meas', dataVec, 'fwd_model', fwdModel);
            else
                warning('Reconstruction:FrequencyNotFound', ...
                        'Frequency %s not found in measurement %s.', frequencyKey, measurementName);
            end
        end

        function config = generateReconstructionConfig(data, solvers, priors, hyperparameter_values)
            % Generate reconstruction configuration.
            iter = 1;
            totalIterations = (length(data) - 1) * length(solvers) * length(priors) * length(hyperparameter_values);
            config(totalIterations) = struct('dataIdx', [], 'solverIdx', [], 'priorIdx', [], 'hyperIdx', []);
        
            for dataIdx = 2:length(data)
                for solverIdx = 1:length(solvers)
                    for priorIdx = 1:length(priors)
                        for hyperIdx = 1:length(hyperparameter_values)
                            config(iter).dataIdx = dataIdx;
                            config(iter).solverIdx = solverIdx;
                            config(iter).priorIdx = priorIdx;
                            config(iter).hyperIdx = hyperIdx;
                            iter = iter + 1;
                        end
                    end
                end
            end
        end

        function plotAllMeasurements(eidorsData, noOfMeasurements, solvers, priors, hyperparameter_values, fwdModel, savePath, iterations)
            % Plot all measurements for the given solvers, priors, and hyperparameters.
            for solverIdx = 1:length(solvers)
                for priorIdx = 1:length(priors)
                    for hyperIdx = 1:length(hyperparameter_values)
                        Reconstruction.visualizeSingleCombination(eidorsData, solverIdx, priorIdx, hyperIdx, noOfMeasurements, solvers, priors, hyperparameter_values, fwdModel, savePath, iterations);
                    end
                end
            end
        end
        
        function [allElemData, invSolveResults] = extractResults(data, numMeasurements, invModel)
            % Handles the extraction of results and preparation for visualization.
            invSolveResults = cell(1, numMeasurements);
            allElemData = [];
            
            for dataIdx = 2:numMeasurements
                invSolveResults{dataIdx} = inv_solve(invModel, data{1}, data{dataIdx});
            end
        
            for dataIdx = 2:numMeasurements
                imgr = invSolveResults{dataIdx};
                if isfield(imgr, 'node_data')
                    allElemData = [allElemData; real(imgr.node_data)];
                else
                    allElemData = [allElemData; real(imgr.elem_data)];
                end
            end
        end

        function visualizeSingleCombination(data, solverIdx, priorIdx, hyperIdx, measurements, solvers, priors, hyperparameter_values, fwdModel, savePath, iterations)
            % Visualize a single combination of solver, prior, and hyperparameter.
        
            solver = solvers{solverIdx};
            prior = priors{priorIdx};
            hyperparameter = hyperparameter_values{hyperIdx};
        
            invModel = Reconstruction.createInverseModel(1, solver, prior, hyperparameter, fwdModel, iterations);
        
            numMeasurements = min(length(data), measurements);
            cols = min(numMeasurements - 1, 5);
            rows = ceil((numMeasurements - 1) / cols);
        
            [allElemData, invSolveResults] = Reconstruction.extractResults(data, numMeasurements, invModel);
        
            fig = figure('Visible', 'off');
            colormap(jet);
            cmin = min(real(allElemData));
            cmax = max(real(allElemData));
        
            for dataIdx = 2:numMeasurements
                subplot(rows, cols, dataIdx - 1);
                imgr = invSolveResults{dataIdx};
                Reconstruction.plotDataField(imgr, fwdModel);
        
                view(2);
                axis off;
                axis equal tight;
                clim([cmin cmax]);
        
                title(sprintf("Measurement %d", dataIdx - 1), 'FontSize', 15);
            end
        
            colorbar('Position', [0.92, 0.1, 0.02, 0.8], 'FontSize', 18);
       
            set(fig, 'Position', [100, 100, 1400, 800]);
            set(fig, 'PaperPositionMode', 'auto');
            set(fig, 'PaperPosition', [0 0 14 8]);
            set(fig, 'PaperSize', [14 8]);
        
            try
                resolution = 800;
                savePathFile = Reconstruction.generateSavePath(savePath, hyperparameter, prior, solver, "single.png");
                print(fig, savePathFile, '-dpng', ['-r', num2str(resolution)]);
            catch ME
                warning(ME.identifier, '%s', ME.message);
            end
            close(fig);
        end

        function performReconstructionAndVisualize(data, dataIdx, solverIdx, priorIdx, hyperIdx, solvers, priors, hyperparameter_values, savePath, fwdModel, iterations)
            % Perform the reconstruction and visualize the results.
            solver = solvers{solverIdx};
            prior = priors{priorIdx};
            hyperparameter = hyperparameter_values{hyperIdx};
        
            if strcmp(func2str(solver), 'inv_solve_TV_pdipm')
                invModel = Reconstruction.initializeTVModel(solver, hyperparameter, fwdModel);
            else
                invModel = Reconstruction.createInverseModel(dataIdx, solver, prior, hyperparameter, fwdModel, iterations);
            end
        
            imgr = inv_solve(invModel, data{1}, data{dataIdx});
            Reconstruction.eidorsReconstruction(imgr, savePath, prior, hyperparameter, solver);
        end

        function invModel = initializeTVModel(solver, hyperparameter, fwdModel)
            % Initialize the Total Variation (TV) model.
            invModel = eidors_obj('inv_model', 'TV_EIT_inverse');
            invModel.reconst_type = 'difference';
            invModel.jacobian_bkgnd.value = 1;
            invModel.hyperparameter.value = hyperparameter;
            invModel.solve = solver;
            invModel.R_prior = @prior_TV;
            invModel.parameters.term_tolerance = 1e-4;
            invModel.parameters.keep_iterations = 0;
            invModel.fwd_model = fwdModel;
            invModel.fwd_model = mdl_normalize(invModel.fwd_model, 1);
            invModel.inv_solve_gn.max_iterations = 10;
        end

        function invModel = createInverseModel(dataIdx, solver, prior, hyperparameter, fwdModel, iterations)
            % Create the inverse model for the reconstruction.
            invModel = eidors_obj('inv_model', ['EIT_inverse_', num2str(dataIdx)]);
            invModel.reconst_type = 'difference';
            invModel.jacobian_bkgnd.value = 1;
            invModel.fwd_model = fwdModel;
            invModel.solve = solver;
            invModel.inv_solve_gn.max_iterations = iterations;
            invModel.RtR_prior = prior;
            invModel.hyperparameter.value = hyperparameter;
        end

        function eidorsReconstruction(imgr, savePath, prior, hyperparameter, solver)
            % Visualize and save the EIDORS reconstruction results.
            savePathFile = Reconstruction.generateSavePath(savePath, hyperparameter, prior, solver, "Simple.png");
            figure;
            Reconstruction.plotDataField(imgr, imgr.fwd_model);
            saveas(gcf,savePathFile);
            close;
        end

        function plotDataField(imgr, fwdModel)
            % Extracts data field and plots it using trisurf.
            if isfield(imgr, 'node_data')
                dataField = real(imgr.node_data);
                trisurf(fwdModel.elems, ...
                    fwdModel.nodes(:, 1), ...
                    fwdModel.nodes(:, 2), ...
                    zeros(size(fwdModel.nodes(:, 1))), ...
                    'FaceVertexCData', dataField, ...
                    'EdgeColor', [0.1, 0.1, 0.1], ...
                    'LineWidth', 0.001, ...
                    'EdgeAlpha', 0.15);
                shading interp;
            else
                trisurf(imgr.fwd_model.elems, ...
                    imgr.fwd_model.nodes(:, 1), ...
                    imgr.fwd_model.nodes(:, 2), ...
                    zeros(size(imgr.fwd_model.nodes(:, 1))), ...
                    real(imgr.elem_data), ...
                    'FaceColor', 'flat', ...
                    'CData', real(imgr.elem_data), ...
                    'EdgeColor', [0.1, 0.1, 0.1], ...
                    'LineWidth', 0.001, ...
                    'EdgeAlpha', 0.15);
            end

            view(2);
            axis off;
            axis equal tight;
        end

        function animateAllMeasurements(data, noOfMeasurements, solvers, priors, hyperparameter_values, fwdModel, savePath, iterations)
            % Animate the visualization of all measurements for given solvers, priors, and hyperparameters.
            
            solver = solvers{1};
            prior = priors{1};
            hyperparameter = hyperparameter_values{1};
            videoPath = Reconstruction.generateSavePath(savePath, hyperparameter, prior, solver, "animation.mp4");
            v = VideoWriter(videoPath, 'MPEG-4');
            v.FrameRate = 2; 
            open(v);
            invModel = Reconstruction.createInverseModel(1, solver, prior, hyperparameter, fwdModel, iterations);
        
            numMeasurements = length(data);
            if numMeasurements > noOfMeasurements
                numMeasurements = noOfMeasurements;
            end

            invSolveResults = cell(1, numMeasurements);
            allElemData = [];
        
            for dataIdx = 2:numMeasurements
                invSolveResults{dataIdx} = inv_solve(invModel, data{1}, data{dataIdx});
                imgr = invSolveResults{dataIdx};
                
                if isfield(imgr, 'node_data')
                    allElemData = [allElemData; real(imgr.node_data)];
                else
                    allElemData = [allElemData; real(imgr.elem_data)];
                end
            end
        
            cmin = min(real(allElemData));
            cmax = max(real(allElemData));
            save_path_colorbar = Reconstruction.generateSavePath(savePath, hyperparameter, prior, solver,"colorbar.png");
            Reconstruction.saveColorbar(cmin, cmax, save_path_colorbar);
            fig = figure('Visible', 'off');
            colormap(jet);

            for dataIdx = 2:numMeasurements
                imgr = invSolveResults{dataIdx};
        
                Reconstruction.plotDataField(imgr, imgr.fwd_model);
        
                clim([cmin cmax]);
        
                title(sprintf('Measurement %d', dataIdx - 1), 'FontSize', 18);
        
                frame = getframe(fig);
                writeVideo(v, frame);
            end
        
            close(v);
            close(fig);
        end

        function animateHyperparameterEffect(data, solvers, priors, hyperparameter_values, fwdModel, savePath, iterations, measurementIdx)
            % Animate the effect of different hyperparameters on a single reconstruction.
            videoFilename = fullfile(savePath, 'hyperparameter_effect_animation.mp4');
            v = VideoWriter(videoFilename, 'MPEG-4');
            v.FrameRate = 4;
            open(v);
            
            numHyperparameters = length(hyperparameter_values);
            allElemData = [];
            invSolveResults = cell(numHyperparameters, 1);
            
            for hyperIdx = 1:numHyperparameters
                solver = solvers{1};
                prior = priors{1};
                hyperparameter = hyperparameter_values{hyperIdx};
        
                if strcmp(func2str(solver), 'inv_solve_TV_pdipm')
                    invModel = Reconstruction.initializeTVModel(solver, hyperparameter, fwdModel);
                else
                    invModel = Reconstruction.createInverseModel(1, solver, prior, hyperparameter, fwdModel, iterations);
                end
                
                invSolveResults{hyperIdx} = inv_solve(invModel, data{1}, data{measurementIdx});
        
                imgr = invSolveResults{hyperIdx};
                if isfield(imgr, 'node_data')
                    allElemData = [allElemData; real(imgr.node_data)];
                else
                    allElemData = [allElemData; real(imgr.elem_data)];
                end
            end
        
            cmin = min(real(allElemData));
            cmax = max(real(allElemData));
            save_path_colorbar = Reconstruction.generateSavePath(savePath, hyperparameter, prior, solver,"colorbar.png");
            Reconstruction.saveColorbar(cmin, cmax, save_path_colorbar);
        
            fig = figure('Visible', 'off');
            colormap(jet);
            
            clim([cmin cmax]);
        
            for hyperIdx = 1:numHyperparameters
                imgr = invSolveResults{hyperIdx};
                
                cla;
        
                Reconstruction.plotDataField(imgr, imgr.fwd_model);
        
                clim([cmin cmax]);
        
                value = hyperparameter_values{hyperIdx};
                if value == 1
                    titleString = '1';
                else
                    exponent = floor(log10(value));
                    mantissa = value / 10^exponent;
                    titleString = sprintf('\\lambda = %.2f \\times 10^{%d}', mantissa, exponent);
                end
                title(titleString, 'FontSize', 18);
        
                frame = getframe(fig);
                writeVideo(v, frame);
            end
        
            close(v);
            close(fig);
        end
        
        function visualizeGroupedReconstructions(data, groupBy, solvers, priors, hyperparameter_values, fwdModel, basePath, iterations, measurementIdx)
            % Visualize grouped reconstructions based on the specified parameter.
        
            switch groupBy
                case 'hyperparameter'
                    numGroups = length(hyperparameter_values);
                    getConfig = @(i) deal(solvers{1}, priors{1}, hyperparameter_values{i});
                case 'solver'
                    numGroups = length(solvers);
                    getConfig = @(i) deal(solvers{i}, priors{1}, hyperparameter_values{1});
                case 'prior'
                    numGroups = length(priors);
                    getConfig = @(i) deal(solvers{1}, priors{i}, hyperparameter_values{1});
                otherwise
                    error('Invalid grouping parameter. Use "hyperparameter", "solver", or "prior".');
            end
        
            allElemData = [];
            invSolveResults = cell(1, numGroups);
        
            for groupIdx = 1:numGroups
                [solver, prior, hyperparameter] = getConfig(groupIdx);
        
                if strcmp(func2str(solver), 'inv_solve_TV_pdipm')
                    invModel = Reconstruction.initializeTVModel(solver, hyperparameter, fwdModel);
                else
                    invModel = Reconstruction.createInverseModel(1, solver, prior, hyperparameter, fwdModel, iterations);
                end
        
                imgr = inv_solve(invModel, data{1}, data{measurementIdx});
                invSolveResults{groupIdx} = imgr;  
                
                if isfield(imgr, 'node_data')
                    allElemData = [allElemData; real(imgr.node_data)];
                else
                    allElemData = [allElemData; real(imgr.elem_data)];
                end
            end
        
            cmin = min(real(allElemData));
            cmax = max(real(allElemData));
            fig = figure('Visible', 'off');
            colormap(jet);
        
            for groupIdx = 1:numGroups
                subplot(ceil(numGroups / 5), 5, groupIdx);
                imgr = invSolveResults{groupIdx};
                Reconstruction.plotDataField(imgr, fwdModel);
                clim([cmin, cmax]);
        
                switch groupBy
                    case 'hyperparameter'
                        value = hyperparameter_values{groupIdx};
                        if value == 1
                            titleString = '\lambda = 1';
                        else
                            exponent = floor(log10(value));
                            mantissa = value / 10^exponent;
                            titleString = sprintf('\\lambda = %.2f \\times 10^{%d}', mantissa, exponent);
                        end
                    case 'solver'
                        solverName = replace(func2str(solvers{groupIdx}), '_', ' ');
                        titleString = sprintf('%s', solverName);
                    case 'prior'
                        priorName = replace(func2str(priors{groupIdx}), '_', ' ');
                        titleString = sprintf('\\sigma_{prior} = %s', priorName);
                end
                title(titleString, 'FontSize', 18);
            end
        
            savePath = Reconstruction.generateSavePath(basePath, hyperparameter, prior, solver, 'GroupedReconstructions.png');
            saveas(fig, savePath);
            close(fig);
        end

        function saveColorbar(cmin, cmax, savePath) 
            fig = figure('Visible', 'off');
            colormap(jet);
            clim([cmin, cmax]);
            colorbar;
            
            saveas(fig, savePath);
            close(fig);
        end

        function savePath = generateSavePath(basePath, hyperparameter, prior, solver, reconstructionType)
            % Generates a save path based on the hyperparameter, prior, solver, and reconstruction type.
            priorName = replace(func2str(prior), '_', ' ');
            solverName = replace(func2str(solver), '_', ' ');
            
            if hyperparameter == 1
                hyperparameterStr = '1';
            else
                exponent = floor(log10(hyperparameter));
                mantissa = hyperparameter / 10^exponent;
                hyperparameterStr = sprintf('%.2fxe%d', mantissa, exponent);
            end
            
            dirName = sprintf('%s_%s_%s_%s', solverName, priorName, hyperparameterStr, reconstructionType);
            dirName = replace(dirName, ' ', '_');

            savePath = fullfile(basePath, dirName);
        end

    end
end
