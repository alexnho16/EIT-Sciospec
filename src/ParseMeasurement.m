clc;
close all;
addpath(genpath(pwd));

%% Set up EIDORS and Netgen paths
% Netgen is only needed on macOS/Windows; it is included in EIDORS on other platforms.
basePath = fullfile('eidors-v3.11', 'eidors', 'startup.m');
netgen_path = 'Netgenpath';
setup_eidors(basePath, netgen_path);

%% Load measurement data and parameters
% Select the directory containing good measurements and parse the measurement file.
path = selectMeasurementDirectory(fullfile(pwd, 'Measurements'));
[measurement, params] = parseMeasurementFile(path, false);

%% Extract parameters from the params structure
% Retrieve key parameters such as input/output channels, current, frequencies, channels, and measurement names.
inputChannels = params.InputChannels;
outputChannels = params.OutputChannels;
current = params.MeasurementCurrent;
frequencies = params.MeasurementFrequencies;
channels = params.MeasurementChannels;
names = params.MeasurementNames;

%% Convert measurements to adjacent mode
% Transform the measurements into the adjacent stimulation pattern.
measurements = Data.convertAllToAdjacent(measurement);

%% Set up forward model
% Create a forward model using a water model grid, setting up stimulation patterns and parameters.
gridSize = 1;
fwdModel = Model.getElastomerModel(gridSize);
removeTwoWireMeasurements = true;
fwdModel = Model.setStimulation(fwdModel, inputChannels, outputChannels, channels, current, removeTwoWireMeasurements);

%% Create EIDORS data for the first frequency
% Set the frequency index and component type for EIDORS data creation.
frequencyIndex = 1;
componentType = "complex";
eidorsData = Reconstruction.createEidorsData(measurements, params, frequencyIndex, componentType, fwdModel);

%% Set up priors
% Define the prior information used in the reconstruction process.
priors = Reconstruction.setPriors('laplace');

%% Set up solvers
% Select the solver algorithm(s) used for the EIT reconstruction.
solvers = Reconstruction.setSolver('nodal');

%% Set up hyperparameters
% Define the hyperparameter values and number of iterations for the reconstruction process.
hyperparameterValues = num2cell(logspace(-5, -1, 25));
iterations = 3;

%% Set up save path
% Define the directory where the results will be saved and ensure it exists.
savePath = 'Path';
checkAndCreateSavePath(savePath);

%% Run the time-difference EIT reconstruction
%Reconstruction.startTimeDifferenceEIT(eidorsData,solvers,priors,hyperparameterValues,fwdModel,savePath,iterations);

%% Alternatively, visualize all combinations
Reconstruction.plotAllMeasurements(eidorsData, 6, solvers, priors, hyperparameterValues, fwdModel, savePath, iterations);

%% Visualize all combinations on hyperparameters, solvers, and priors for one measurement
lambda_values = num2cell(logspace(-5, -2, 25));
measurementIdx = 2;
%Reconstruction.visualizeGroupedReconstructions(eidorsData, "hyperparameter", solvers, prio  rs, lambda_values, fwdModel, savePath, iterations, measurementIdx);

%% Animate the effect of different hyperparameters on a single reconstruction
%Reconstruction.animateHyperparameterEffect(eidorsData, solvers, priors, lambda_values, fwdModel, savePath, iterations, 5);

%% Animate all measurements
% Create an animation for all measurements using the defined parameters.
priors = Reconstruction.setPriors('laplace');
solvers = Reconstruction.setSolver('nodal');
lambda_values = 0.05;
%Reconstruction.animateAllMeasurements(eidorsData, 24, solvers, priors, hyperparameterValues, fwdModel, savePath, iterations);
