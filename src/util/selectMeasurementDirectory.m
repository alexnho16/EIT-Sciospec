function selectedPath = selectMeasurementDirectory(defaultPath)
    % selectMeasurementDirectory prompts the user to select a directory for measurement files.
    %
    % Parameters:
    %   defaultPath (string): The default path to start the directory selection.
    %
    % Returns:
    %   selectedPath (string): The path to the selected directory.
    %   If no directory is selected, an error is thrown.

    % Use uigetdir to allow the user to select a directory
    selectedPath = uigetdir(defaultPath, 'Select Parent Directory for Measurement Files');
    
    % Check if a directory was selected
    if selectedPath == 0
        error('No folder selected. Exiting script.');
    end
end