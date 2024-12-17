classdef Model
    methods (Static)
        function fwdModel = getElastomerModel(gridsize)
            % Sets up the Elastomer model with default dimensions and generates the forward model
            fwdModel = Model.setModelDimensions(40, 50, 4, 4, gridsize);
            fwdModel.electrodePositions = Model.calculateElectrodePositions(fwdModel.width, fwdModel.height, fwdModel.nElecWidth, fwdModel.nElecHeight);
            fwdModel = Model.generateModel(fwdModel.width, fwdModel.height, fwdModel.gridSize, fwdModel.electrodePositions);
        end

        function fwdModel = getWaterModel(gridsize)
            % Sets up the Water model with default dimensions and generates the forward model
            fwdModel = Model.setModelDimensions(40, 80, 4, 4, gridsize);
            fwdModel.electrodePositions = Model.calculateElectrodePositionsWithCorners(fwdModel.width, fwdModel.height, fwdModel.nElecWidth, fwdModel.nElecHeight);
            fwdModel = Model.generateModel(fwdModel.width, fwdModel.height, fwdModel.gridSize, fwdModel.electrodePositions);
        end
        
        %% New models can be added here (also add it in the app) in the same style as 'getWaterModel'

        function fwdModel = getModel(width, height, nElecWidth, nElecHeight, gridSize, useCorners)
            % Allows custom model dimensions and electrode positioning
            if useCorners
                fwdModel = Model.setModelDimensions(width, height, nElecWidth, nElecHeight, gridSize);
                fwdModel.electrodePositions = Model.calculateElectrodePositionsWithCorners(width, height, nElecWidth, nElecHeight);
            else
                fwdModel = Model.setModelDimensions(width, height, nElecWidth, nElecHeight, gridSize);
                fwdModel.electrodePositions = Model.calculateElectrodePositions(width, height, nElecWidth, nElecHeight);
            end
            fwdModel = Model.generateModel(width, height, gridSize, fwdModel.electrodePositions);
        end

        function fwdModel = setModelDimensions(width, height, nElecWidth, nElecHeight, gridSize)
            % Creates and returns a structure to hold model dimensions and properties
            fwdModel.width = width;
            fwdModel.height = height;
            fwdModel.nElecWidth = nElecWidth;
            fwdModel.nElecHeight = nElecHeight;
            fwdModel.gridSize = gridSize;
        end

        function electrodePositions = calculateElectrodePositionsWithCorners(width, height, nElecWidth, nElecHeight)
            % Calculates the electrode positions including the corners
            dx = width / nElecWidth;
            dy = height / nElecHeight;

            % Top electrodes
            topX = (0:dx:width-dx)';
            topY = repmat(height, length(topX), 1);
            topElectrodes = [topX, topY];

            % Right electrodes
            rightX = repmat(width, nElecHeight, 1);
            rightY = (height:-dy:dy)';
            rightElectrodes = [rightX, rightY];

            % Bottom electrodes
            bottomX = (width:-dx:dx)';
            bottomY = zeros(length(bottomX), 1);
            bottomElectrodes = [bottomX, bottomY];

            % Left electrodes
            leftX = zeros(nElecHeight, 1);
            leftY = (0:dy:height-dy)';
            leftElectrodes = [leftX, leftY];

            electrodePositions = [
                topElectrodes;
                rightElectrodes;
                bottomElectrodes;
                leftElectrodes
                ];
        end

        function electrodePositions = calculateElectrodePositions(width, height, nElecWidth, nElecHeight)
            % Calculates the electrode positions excluding the corners
            dx = width / (nElecWidth + 1);
            dy = height / (nElecHeight + 1);

            % Top electrodes
            topX = (dx:dx:width-dx)';
            topY = repmat(height, length(topX), 1);
            topElectrodes = [topX, topY];

            % Right electrodes
            rightX = repmat(width, nElecHeight, 1);
            rightY = (height-dy:-dy:dy)';
            rightElectrodes = [rightX, rightY];

            % Bottom electrodes
            bottomX = (width-dx:-dx:dx)';
            bottomY = zeros(length(bottomX), 1);
            bottomElectrodes = [bottomX, bottomY];

            % Left electrodes
            leftX = zeros(nElecHeight, 1);
            leftY = (dy:dy:height-dy)';
            leftElectrodes = [leftX, leftY];

            electrodePositions = [
                topElectrodes;
                rightElectrodes;
                bottomElectrodes;
                leftElectrodes
                ];
        end

        function fwdModel = generateModel(width, height, gridSize, electrodePositions)
            % Generates the forward model based on the dimensions and electrode positions
            outer_shape = [0, 0; width, 0; width, height; 0, height];

            fwdModel = ng_mk_2d_model({outer_shape, gridSize}, electrodePositions, [2, 10]);

            fwdModel.system_mat = 'system_mat_1st_order';
            fwdModel.jacobian = 'jacobian_adjoint';
            for i = 1:length(electrodePositions)
                fwdModel.electrode(i).z_contact = 0.01;
            end
        end

        function fwdModel = setStimulation(fwdModel, inputChannels, outputChannels, measurementChannels, amplitudeCurrent, removeTwoWireMeasurements)
            % Sets a custom stimulation pattern
            channelNumber = measurementChannels;
            stimulation = struct();
            meas_select_matrix = ones(channelNumber, length(inputChannels));
            for i = 1:length(inputChannels)
                stimulation(i).stimulation = 'Amp';
                stimulation(i).stim_pattern = sparse(channelNumber, 1);
                stimulation(i).stim_pattern(inputChannels(i)) = amplitudeCurrent;
                stimulation(i).stim_pattern(outputChannels(i)) = -amplitudeCurrent;
                stimulation(i).meas_pattern = Model.generateMeasPattern(inputChannels(i), outputChannels(i), channelNumber, removeTwoWireMeasurements);

                previous_output_channel = mod(outputChannels(i) + channelNumber - 2, channelNumber) + 1;
                meas_select_matrix(previous_output_channel, i) = 0;

                previous_input_channel = mod(inputChannels(i) + channelNumber - 2, channelNumber) + 1;
                meas_select_matrix(previous_input_channel, i) = 0;

                meas_select_matrix(outputChannels(i), i) = 0;
                meas_select_matrix(inputChannels(i), i) = 0;
            end
            meas_select_log = logical(meas_select_matrix(:));
            if removeTwoWireMeasurements
                fwdModel.meas_select = meas_select_log;
            end
            fwdModel.stimulation = stimulation;
            fwdModel.get_all_meas = 0;
        end

        function meas_pattern = generateMeasPattern(inj_from, inj_to, total_electrodes, removeTwoWireMeasurements)
            % Generates a measurement pattern
            meas_pattern_full = zeros(total_electrodes, total_electrodes);

            for i = 1:total_electrodes
                next_electrode = mod(i, total_electrodes) + 1;
                meas_pattern_full(i, i) = 1;
                meas_pattern_full(i, next_electrode) = -1;
            end

            if removeTwoWireMeasurements
                prev_inj = mod(inj_from - 2, total_electrodes) + 1;
                rows_to_exclude = [prev_inj, inj_from];

                if mod(inj_from, total_electrodes) + 1 == inj_to
                    rows_to_exclude = [rows_to_exclude, inj_to];
                else
                    prev_ret = mod(inj_to - 2, total_electrodes) + 1;
                    rows_to_exclude = [rows_to_exclude, inj_to, prev_ret];
                end

                rows_to_exclude = unique(rows_to_exclude);

                meas_pattern_full(rows_to_exclude, :) = [];
            end

            meas_pattern = sparse(meas_pattern_full);
        end

        function visualizeMeasurementSelectionForInjections(fwdModel, inputChannels, outputChannels)
            % Visualizes the measurement selection for each injection
            numStims = length(fwdModel.stimulation);

            for i = 1:numStims
                figure;
                hold on;

                measPattern = full(fwdModel.stimulation(i).meas_pattern);
                [rows, columns] = size(measPattern);
                [X, Y] = meshgrid(1:columns, 1:rows);

                imagesc(X(1, :), Y(:, 1), measPattern);
                colormap([1 0 0; 1 1 1; 0 0 1]);
                clim([-1 1]);
                hColorbar = colorbar;
                set(hColorbar, 'FontSize', 18);

                title(sprintf('Stimulation Pattern %d to %d', inputChannels(i), outputChannels(i)), 'FontSize', 18, 'FontWeight', 'bold');
                xlabel('Channels', 'FontSize', 16, 'FontWeight', 'bold');
                ylabel('Measurement', 'FontSize', 16, 'FontWeight', 'bold');
                set(gca, 'XTick', 1:columns, 'YTick', 1:rows, ...
                    'XTickLabel', 1:columns, 'YTickLabel', 1:rows, ...
                    'XAxisLocation', 'top', 'YAxisLocation', 'left', 'FontSize', 18, 'FontWeight', 'bold');

                grid on;
                set(gca, 'GridLineStyle', '--', 'GridColor', 'k', 'GridAlpha', 0.6);
                set(gca, 'Layer', 'top');

                for srcRow = 1:rows
                    for srcCol = 1:columns
                        if measPattern(srcRow, srcCol) == 1
                            sinkCols = find(measPattern(srcRow, :) == -1);
                            for sinkCol = sinkCols
                                quiver(srcCol, srcRow, sinkCol - srcCol, 0, 0, ...
                                    'MaxHeadSize', 0.5, 'Color', 'k', 'AutoScale', 'on', 'LineWidth', 2);
                            end
                        end
                    end
                end

                set(gcf, 'Color', 'w');
                set(gca, 'Box', 'on');

                hold off;
            end
        end

        function visualizeInjectionMeasurementMatrix(fwdModel, measurementChannels, inputChannels, outputChannels)
            % Visualizes the injection measurement matrix when the matrix is not necessarily square
            numStims = length(fwdModel.stimulation); % Number of stimulations (rows)
            numChannels = measurementChannels;       % Number of measurement channels (columns)

            meas_select_matrix = reshape(fwdModel.meas_select, numChannels, numStims)';

            figure;
            hold on;

            [X, Y] = meshgrid(1:numChannels, 1:numStims);
            plot(X, Y, 's', 'MarkerSize', 10, 'MarkerEdgeColor', 'none', 'MarkerFaceColor', [0.9 0.9 0.9]);

            for k = 1:numStims
                for j = 1:numChannels
                    if meas_select_matrix(k, j)
                        plot(j, k, 'g^', 'MarkerSize', 14, 'MarkerFaceColor', 'g');
                    else
                        plot(j, k, 'r^', 'MarkerSize', 14, 'MarkerFaceColor', 'r');
                    end
                end
            end

            % Add labels for input and output current channels
            for i = 1:numStims
                text(inputChannels(i), i, 'X', 'Color', 'k', 'FontSize', 20, ...
                    'HorizontalAlignment', 'center', 'FontWeight', 'bold');
                text(outputChannels(i), i, 'O', 'Color', 'k', 'FontSize', 20, ...
                    'HorizontalAlignment', 'center', 'FontWeight', 'bold');
            end

            axis equal;
            grid on;
            axis([0 numChannels + 1 0 numStims + 1]);
            set(gca, 'XTick', 1:numChannels, 'YTick', 1:numStims, ...
                'XTickLabel', num2str((1:numChannels)'), 'YTickLabel', num2str((1:numStims)'), ...
                'XAxisLocation', 'top', 'YAxisLocation', 'left', 'TickLength', [0 0], 'FontSize', 20, 'FontWeight', 'bold');

            xlabel('Measurement Channels', 'FontSize', 20, 'FontWeight', 'bold');
            ylabel('Stimulations', 'FontSize', 20, 'FontWeight', 'bold');
            title('Measurement Selection Grid', 'FontSize', 20, 'FontWeight', 'bold');

            set(gcf, 'Color', 'w');
            set(gca, 'Box', 'on');
        end
        function visualizeModel(fwdModel)
            % Visualizes the forward model geometry and electrode positions
            show_fem(fwdModel, [1, 0, 0]);
            hold on;

            width = max(fwdModel.nodes(:, 1)) - min(fwdModel.nodes(:, 1));
            height = max(fwdModel.nodes(:, 2)) - min(fwdModel.nodes(:, 2));

            for i = 1:length(fwdModel.electrode)
                elec_nodes = fwdModel.electrode(i).nodes;
                elec_center = mean(fwdModel.nodes(elec_nodes, :), 1);

                offset = 0.5;

                if elec_center(1) < width / 2
                    hAlign = 'left';
                    xPos = elec_center(1) - offset;
                else
                    hAlign = 'right';
                    xPos = elec_center(1) + offset;
                end

                if elec_center(2) < height / 2
                    vAlign = 'top';
                    yPos = elec_center(2) - offset;
                else
                    vAlign = 'bottom';
                    yPos = elec_center(2) + offset;
                end

                text(xPos, yPos, sprintf('%d', i), ...
                    'VerticalAlignment', vAlign, 'HorizontalAlignment', hAlign, ...
                    'Color', 'b', 'FontSize', 22);
            end

            axis equal;
            grid off;
            set(gca, 'xtick', [], 'ytick', []);
            hold off;
        end
    end
end
